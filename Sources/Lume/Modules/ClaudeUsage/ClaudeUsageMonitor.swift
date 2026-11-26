import Foundation

@MainActor
final class ClaudeUsageMonitor: ObservableObject {
    @Published private(set) var entries: [UsageEntry] = []
    @Published private(set) var closedPercent: Int?

    private let present: (UsageAlert) -> Void
    private var config = ClaudeUsageModuleConfig()
    private var accountNames: [String: String] = [:]
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private var alerted: [String: Int] = [:]
    private var hasBaseline = false

    init(present: @escaping (UsageAlert) -> Void) {
        self.present = present
    }

    func apply(_ newConfig: ClaudeUsageModuleConfig, accountNames names: [String: String]) {
        config = newConfig
        accountNames = names
        if newConfig.enabled, observer == nil {
            observer = DistributedNotificationCenter.default().addObserver(forName: UsageStatusLine.notification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            }
            timer = Timer.scheduledTimer(withTimeInterval: UsageLayout.refresh, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateClosed() }
            }
        } else if !newConfig.enabled, let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
            timer?.invalidate()
            timer = nil
            hasBaseline = false
            alerted = [:]
        }
        if newConfig.enabled {
            reload()
        } else {
            entries = []
            closedPercent = nil
        }
    }

    private func reload() {
        let snapshots = UsageStore.loadAll()
        entries = snapshots
            .map { UsageEntry(name: name(for: $0.account), snapshot: $0) }
            .sorted { lhs, rhs in
                lhs.snapshot.updatedAt != rhs.snapshot.updatedAt ? lhs.snapshot.updatedAt > rhs.snapshot.updatedAt : lhs.name < rhs.name
            }
        checkThresholds(snapshots)
        updateClosed()
    }

    private func name(for account: String) -> String {
        accountNames[account] ?? ClaudeAccount(directory: URL(fileURLWithPath: account)).defaultName
    }

    private func updateClosed() {
        let now = Date()
        let lowest = config.alertThresholds.min() ?? 100
        let peak = entries.map { $0.peak(at: now) }.max() ?? 0
        closedPercent = config.showWhenClosed && peak >= lowest ? peak : nil
    }

    private func checkThresholds(_ snapshots: [UsageSnapshot]) {
        let now = Date()
        let thresholds = config.alertThresholds.sorted()
        for snapshot in snapshots {
            for kind in [UsageWindowKind.fiveHour, .sevenDay] {
                guard let window = snapshot.window(kind) else { continue }
                let key = "\(snapshot.account)|\(kind.rawValue)|\(Int(window.resetsAt.timeIntervalSince1970))"
                let reached = thresholds.last { window.used(at: now) >= $0 } ?? 0
                let previous = alerted[key] ?? 0
                guard reached > previous else { continue }
                alerted[key] = reached
                if hasBaseline {
                    present(UsageAlert(account: name(for: snapshot.account), window: kind, threshold: reached, resetsAt: window.resetsAt))
                }
            }
        }
        hasBaseline = true
    }
}
