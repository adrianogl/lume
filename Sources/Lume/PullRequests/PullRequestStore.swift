import Foundation

@MainActor
final class PullRequestStore: ObservableObject {
    @Published private(set) var mine: [PullRequest] = []
    @Published private(set) var review: [PullRequest] = []
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var error: String?

    private let model: NotchModel
    private var timer: Timer?

    init(model: NotchModel) {
        self.model = model
    }

    var ready: [PullRequest] { mine.filter(\.isReadyToMerge) }
    var failingCI: Int { mine.filter { $0.ci == .fail }.count }
    var withComments: Int { mine.filter { $0.comments > 0 }.count }

    func items(for tab: PRTab) -> [PullRequest] {
        switch tab {
        case .mine: return mine
        case .review: return review
        case .ready: return ready
        }
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: PRConfig.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let result = await Task.detached { Result { try PullRequestClient.fetch() } }.value
            switch result {
            case .success(let lists):
                if lastRefresh != nil {
                    PullRequestAlerts.changes(oldMine: mine, newMine: lists.mine, oldReview: review, newReview: lists.review)
                        .forEach(model.present)
                }
                mine = lists.mine
                review = lists.review
                error = nil
                lastRefresh = Date()
            case .failure(let failure):
                error = (failure as? PRError)?.message ?? failure.localizedDescription
            }
            isRefreshing = false
            var category = PRConfig.category
            category.badge = review.isEmpty ? nil : review.count
            model.update(category)
        }
    }
}
