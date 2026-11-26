import AppKit

@MainActor
final class PullRequestMonitor: ObservableObject {
    @Published private(set) var items: [PullRequest] = []
    @Published private(set) var attentionCount = 0
    @Published private(set) var loadState = PRLoadState.idle
    @Published private(set) var login = ""

    private let present: (PRAlert) -> Void
    private var config = PullRequestsModuleConfig()
    private var timer: Timer?
    private var isFetching = false
    private var lastFetch: Date?
    private var knownStates: [URL: PRState]?

    init(present: @escaping (PRAlert) -> Void) {
        self.present = present
    }

    func apply(_ newConfig: PullRequestsModuleConfig) {
        let changed = newConfig != config
        config = newConfig
        guard newConfig.enabled else {
            timer?.invalidate()
            timer = nil
            knownStates = nil
            items = []
            attentionCount = 0
            loadState = .idle
            return
        }
        if changed || timer == nil {
            schedule()
            refresh()
        }
    }

    func refreshIfStale() {
        guard config.enabled else { return }
        if let lastFetch, Date().timeIntervalSince(lastFetch) < PRPolling.staleAfter { return }
        refresh()
    }

    func refresh() {
        guard config.enabled, !isFetching else { return }
        isFetching = true
        if items.isEmpty { loadState = .loading }
        let organizations = config.organizations
        Task.detached(priority: .utility) { [weak self] in
            let result = Result { try GitHubCLI.fetch(organizations: organizations) }
            await self?.finish(result)
        }
    }

    static func open(_ pullRequest: PullRequest) {
        NSWorkspace.shared.open(pullRequest.url)
    }

    private func schedule() {
        timer?.invalidate()
        let interval = TimeInterval(max(config.pollMinutes, 1) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func finish(_ result: Result<GitHubSnapshot, Error>) {
        isFetching = false
        lastFetch = Date()
        guard config.enabled else { return }
        switch result {
        case .success(let snapshot):
            login = snapshot.login
            let visible = snapshot.pullRequests.filter { pr in
                (config.includeDrafts || !pr.isDraft) && (config.includeBots || !pr.isBot)
            }
            announceChanges(in: visible)
            items = visible.sorted { lhs, rhs in
                lhs.state != rhs.state ? lhs.state < rhs.state : lhs.updatedAt > rhs.updatedAt
            }
            attentionCount = items.filter { $0.state.needsYou }.count
            loadState = .ready
        case .failure(GitHubCLIError.missing):
            loadState = .missingCLI
        case .failure(GitHubCLIError.notLoggedIn):
            loadState = .notLoggedIn
        case .failure(GitHubCLIError.failed(let message)):
            loadState = .failed(message)
        case .failure(let error):
            loadState = .failed(error.localizedDescription)
        }
    }

    private func announceChanges(in pullRequests: [PullRequest]) {
        let current = Dictionary(pullRequests.map { ($0.url, $0.state) }, uniquingKeysWith: { first, _ in first })
        defer { knownStates = current }
        guard let previous = knownStates else {
            if ProcessInfo.processInfo.environment[LaunchOptions.demoPullRequest] != nil, let first = pullRequests.min(by: { $0.state < $1.state }) {
                present(PRAlert(state: first.state, pullRequest: first))
            }
            return
        }
        for pr in pullRequests {
            let state = pr.state
            let before = previous[pr.url]
            guard before != state, config.alerts.allows(state) else { continue }
            if state == .approved, before == .readyToMerge { continue }
            present(PRAlert(state: state, pullRequest: pr))
        }
    }
}
