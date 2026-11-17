import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var states: [String: AccountState] = [:]
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isScanningLogs = false
    @Published var menuAccount: String {
        didSet { UserDefaults.standard.set(menuAccount, forKey: UsageConfig.Keys.menuAccount) }
    }
    @Published var alertThreshold: Double {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: UsageConfig.Keys.alertThreshold) }
    }

    let accounts = UsageConfig.accounts
    private let scanners: [String: LogScanner]
    private var limitsTimer: Timer?
    private var logsTimer: Timer?
    private var nextAllowedFetch: [String: Date] = [:]

    init() {
        Self.migrateLegacyDefaults()
        let defaults = UserDefaults.standard
        menuAccount = defaults.string(forKey: UsageConfig.Keys.menuAccount) ?? UsageConfig.automaticAccount
        let threshold = defaults.double(forKey: UsageConfig.Keys.alertThreshold)
        alertThreshold = threshold == 0 ? UsageConfig.defaultAlertThreshold : threshold
        scanners = Dictionary(uniqueKeysWithValues: UsageConfig.accounts.map { ($0.name, LogScanner()) })

        let cached = defaults.data(forKey: UsageConfig.Keys.snapshots)
            .flatMap { try? JSONDecoder().decode([String: LimitSnapshot].self, from: $0) } ?? [:]
        for account in accounts {
            var state = AccountState()
            state.snapshot = cached[account.name]
            states[account.name] = state
            if let fetched = cached[account.name]?.fetchedAt {
                nextAllowedFetch[account.name] = fetched.addingTimeInterval(UsageConfig.minFetchInterval)
            }
        }
    }

    private static func migrateLegacyDefaults() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: UsageConfig.Keys.migrated),
              let legacy = UserDefaults(suiteName: UsageConfig.legacyDefaultsSuite) else { return }
        for key in UsageConfig.Keys.all where defaults.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: UsageConfig.Keys.migrated)
    }

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshAll()
        limitsTimer = Timer.scheduledTimer(withTimeInterval: UsageConfig.limitsInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLimits() }
        }
        logsTimer = Timer.scheduledTimer(withTimeInterval: UsageConfig.logsInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLogs() }
        }
    }

    func refreshAll() {
        refreshLimits()
        refreshLogs()
    }

    func refreshLimits() {
        isRefreshing = true
        Task {
            await withTaskGroup(of: (String, Result<LimitSnapshot, Error>).self) { group in
                let now = Date()
                for account in accounts where (nextAllowedFetch[account.name] ?? .distantPast) <= now {
                    nextAllowedFetch[account.name] = now.addingTimeInterval(UsageConfig.minFetchInterval)
                    group.addTask {
                        do { return (account.name, .success(try await UsageClient.fetch(account))) }
                        catch { return (account.name, .failure(error)) }
                    }
                }
                for await (name, result) in group {
                    switch result {
                    case .success(let snapshot):
                        states[name]?.snapshot = snapshot
                        states[name]?.error = nil
                        recordWeeklyPeak(account: name, window: snapshot.sevenDay)
                        notifyIfNeeded(account: name, snapshot: snapshot)
                    case .failure(UsageError.rateLimited(let retryAfter)):
                        let retry = Date().addingTimeInterval(max(retryAfter ?? UsageConfig.rateLimitFallback, UsageConfig.minFetchInterval))
                        nextAllowedFetch[name] = retry
                        states[name]?.error = "API limitou as consultas · nova tentativa às " + Format.time(retry)
                    case .failure(let error):
                        states[name]?.error = (error as? UsageError)?.message ?? "Sem conexão"
                    }
                }
            }
            persistSnapshots()
            lastRefresh = Date()
            isRefreshing = false
        }
    }

    private func persistSnapshots() {
        let snapshots = states.compactMapValues(\.snapshot)
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: UsageConfig.Keys.snapshots)
        }
    }

    func refreshLogs() {
        let accounts = accounts
        let scanners = scanners
        Task.detached(priority: .utility) {
            let calendar = Calendar.current
            let now = Date()
            let since = calendar.date(byAdding: .day, value: -UsageConfig.scanDays, to: calendar.startOfDay(for: now))!
            let startOfToday = calendar.startOfDay(for: now)
            await MainActor.run { self.isScanningLogs = true }
            for account in accounts {
                guard let scanner = scanners[account.name] else { continue }
                var daily: [Date: Int] = [:]
                var hourly: [Int: Int] = [:]
                for entry in scanner.scan(account, since: since) {
                    daily[calendar.startOfDay(for: entry.date), default: 0] += entry.tokens
                    if entry.date >= startOfToday {
                        hourly[calendar.component(.hour, from: entry.date), default: 0] += entry.tokens
                    }
                }
                let finishedDaily = daily
                let finishedHourly = hourly
                await MainActor.run {
                    self.states[account.name]?.daily = finishedDaily
                    self.states[account.name]?.hourlyToday = finishedHourly
                    self.states[account.name]?.logsLoaded = true
                }
            }
            await MainActor.run { self.isScanningLogs = false }
        }
    }

    var menuBarAccount: (account: Account, snapshot: LimitSnapshot)? {
        let withData = accounts.compactMap { account in states[account.name]?.snapshot.map { (account, $0) } }
        if menuAccount != UsageConfig.automaticAccount, let pick = withData.first(where: { $0.0.name == menuAccount }) {
            return pick
        }
        return withData.max { ($0.1.fiveHour?.utilization ?? 0) < ($1.1.fiveHour?.utilization ?? 0) }
    }

    func tokens(account: String, onDay day: Date) -> Int {
        states[account]?.daily[Calendar.current.startOfDay(for: day)] ?? 0
    }

    func days(last count: Int, excludeWeekends: Bool) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count)
            .map { calendar.date(byAdding: .day, value: -$0, to: today)! }
            .filter { !excludeWeekends || !calendar.isDateInWeekend($0) }
    }

    func tokens(account: String, lastDays count: Int, excludeWeekends: Bool = false) -> Int {
        days(last: count, excludeWeekends: excludeWeekends).reduce(0) { $0 + tokens(account: account, onDay: $1) }
    }

    func weeklyForecast(account: String) -> WeeklyForecast? {
        WeeklyForecaster.forecast(window: states[account]?.snapshot?.sevenDay)
    }

    func weeksAtLimit(account: String) -> Int {
        let cutoff = Date().addingTimeInterval(-UsageConfig.weeksAtLimitWindow)
        let peaks = weeklyPeaks()[account] ?? [:]
        return peaks.filter { key, peak in
            (DateParsing.iso(key) ?? .distantPast) >= cutoff && peak >= 100
        }.count
    }

    private func weeklyPeaks() -> [String: [String: Double]] {
        UserDefaults.standard.dictionary(forKey: UsageConfig.Keys.weeklyPeaks) as? [String: [String: Double]] ?? [:]
    }

    private func recordWeeklyPeak(account: String, window: LimitWindow?) {
        guard let window, let reset = window.resetsAt else { return }
        var all = weeklyPeaks()
        var peaks = all[account] ?? [:]
        let key = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: reset))
        peaks[key] = max(peaks[key] ?? 0, window.utilization)
        all[account] = peaks
        UserDefaults.standard.set(all, forKey: UsageConfig.Keys.weeklyPeaks)
    }

    private func notifyIfNeeded(account: String, snapshot: LimitSnapshot) {
        var notified = UserDefaults.standard.dictionary(forKey: UsageConfig.Keys.notified) as? [String: Bool] ?? [:]
        let windows: [(String, LimitWindow?)] = [("janela de 5h", snapshot.fiveHour), ("limite semanal", snapshot.sevenDay)]
        for (label, window) in windows {
            guard let window, window.utilization >= alertThreshold else { continue }
            let resetKey = window.resetsAt.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "?"
            let key = "\(account)|\(label)|\(resetKey)"
            guard notified[key] != true else { continue }
            notified[key] = true
            let content = UNMutableNotificationContent()
            content.title = "Claude · \(account)"
            content.body = "\(Int(window.utilization))% da \(label) usado" + (window.resetsAt.map { ". Reset \(Format.reset($0))" } ?? "")
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
        }
        UserDefaults.standard.set(notified, forKey: UsageConfig.Keys.notified)
    }
}
