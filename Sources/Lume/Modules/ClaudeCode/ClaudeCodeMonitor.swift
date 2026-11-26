import AppKit

@MainActor
final class ClaudeCodeMonitor: ObservableObject {
    @Published private(set) var pendingCount = 0
    @Published private(set) var entries: [ClaudeSessionEntry] = []

    private let present: (ClaudeAlert) -> Void
    private var config = ClaudeCodeModuleConfig()
    private var observer: NSObjectProtocol?
    private var sessions: [String: ClaudeSessionEntry] = [:]
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
            sessions = [:]
            publish()
        }
    }

    static func open(bundleID: String?, terminalSession: String?) {
        guard let bundleID, !bundleID.isEmpty else { return }
        let script: String
        if bundleID == TerminalScript.itermBundle, let session = terminalSession, !session.isEmpty {
            script = TerminalScript.focusITermSession(session)
        } else {
            script = TerminalScript.reopen(bundleID: bundleID)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            guard error != nil else { return }
            DispatchQueue.main.async { activate(bundleID: bundleID) }
        }
    }

    private static func activate(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func handle(_ info: [String: String]) {
        guard let kind = info[ClaudeHook.Key.kind].flatMap(ClaudeEventKind.init(rawValue:)) else { return }
        let session = info[ClaudeHook.Key.session] ?? ""

        if kind == .resolved {
            if var entry = sessions[session], entry.isWaiting {
                entry.isWaiting = false
                sessions[session] = entry
                publish()
            }
            return
        }
        guard isEnabled(kind) else { return }

        let accountPath = info[ClaudeHook.Key.account] ?? ""
        let account = ClaudeAccount(directory: URL(fileURLWithPath: accountPath))
        let cwd = info[ClaudeHook.Key.cwd] ?? ""
        let alert = ClaudeAlert(
            kind: kind,
            sessionID: session,
            project: cwd.isEmpty ? "" : URL(fileURLWithPath: cwd).lastPathComponent,
            account: config.accountNames[accountPath] ?? account.defaultName,
            message: ClaudeText.translate(info[ClaudeHook.Key.message] ?? ""),
            bundleID: info[ClaudeHook.Key.bundle],
            terminalSession: info[ClaudeHook.Key.terminalSession],
            sessionTitle: info[ClaudeHook.Key.title] ?? ""
        )
        sessions[session] = ClaudeSessionEntry(alert: alert, isWaiting: kind != .finished, updatedAt: Date())
        publish()
        present(alert)
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
        let before = sessions.count
        sessions = sessions.filter { $0.value.updatedAt > limit }
        if sessions.count != before { publish() }
    }

    private func publish() {
        entries = sessions.values.sorted { lhs, rhs in
            if lhs.isWaiting != rhs.isWaiting { return lhs.isWaiting }
            if lhs.isWaiting, lhs.alert.kind != rhs.alert.kind { return lhs.alert.kind == .permission }
            return lhs.updatedAt > rhs.updatedAt
        }
        pendingCount = entries.filter(\.isWaiting).count
    }
}
