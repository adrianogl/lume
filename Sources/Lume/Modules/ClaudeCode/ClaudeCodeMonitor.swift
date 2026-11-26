import AppKit

@MainActor
final class ClaudeCodeMonitor: ObservableObject {
    @Published private(set) var pendingCount = 0

    private let present: (ClaudeAlert) -> Void
    private var config = ClaudeCodeModuleConfig()
    private var observer: NSObjectProtocol?
    private var pending: [String: Date] = [:]
    private var cleanupTimer: Timer?

    init(present: @escaping (ClaudeAlert) -> Void) {
        self.present = present
    }

    func apply(_ newConfig: ClaudeCodeModuleConfig) {
        config = newConfig
        if newConfig.enabled, observer == nil {
            observer = DistributedNotificationCenter.default().addObserver(forName: ClaudeHook.notification, object: nil, queue: .main) { [weak self] notification in
                let info = notification.userInfo as? [String: String] ?? [:]
                MainActor.assumeIsolated { self?.handle(info) }
            }
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: ClaudeHook.cleanupInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.dropStale() }
            }
        } else if !newConfig.enabled, let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
            cleanupTimer?.invalidate()
            cleanupTimer = nil
            pending = [:]
            publishCount()
        }
    }

    static func open(bundleID: String?) {
        guard let bundleID, !bundleID.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func handle(_ info: [String: String]) {
        guard let kind = info[ClaudeHook.Key.kind].flatMap(ClaudeEventKind.init(rawValue:)) else { return }
        let session = info[ClaudeHook.Key.session] ?? ""

        if kind == .resolved {
            if pending.removeValue(forKey: session) != nil { publishCount() }
            return
        }
        guard isEnabled(kind) else { return }

        pending[session] = Date()
        publishCount()

        let accountPath = info[ClaudeHook.Key.account] ?? ""
        let account = ClaudeAccount(directory: URL(fileURLWithPath: accountPath))
        let cwd = info[ClaudeHook.Key.cwd] ?? ""
        present(ClaudeAlert(
            kind: kind,
            sessionID: session,
            project: cwd.isEmpty ? "" : URL(fileURLWithPath: cwd).lastPathComponent,
            account: config.accountNames[accountPath] ?? account.defaultName,
            message: ClaudeText.translate(info[ClaudeHook.Key.message] ?? ""),
            bundleID: info[ClaudeHook.Key.bundle]
        ))
    }

    private func isEnabled(_ kind: ClaudeEventKind) -> Bool {
        switch kind {
        case .permission: config.permission
        case .waiting: config.waiting
        case .finished: config.finished
        case .resolved: true
        }
    }

    private func dropStale() {
        let limit = Date().addingTimeInterval(-ClaudeHook.staleAfter)
        let before = pending.count
        pending = pending.filter { $0.value > limit }
        if pending.count != before { publishCount() }
    }

    private func publishCount() {
        pendingCount = pending.count
    }
}
