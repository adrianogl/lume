import AppKit

@MainActor
final class CommandMonitor: ObservableObject {
    @Published private(set) var runs: [CommandRun] = []
    @Published private(set) var running: [RunningCommand] = []
    @Published private(set) var status: RunningCommandStatus?

    private let present: (CommandRun) -> Void
    private var config = CommandsModuleConfig()
    private var observer: NSObjectProtocol?
    private var cleanupTimer: Timer?
    private var runningTimer: Timer?
    private var history: [CommandRun] = []
    private var sessions: [String: RunningCommand] = [:]

    init(present: @escaping (CommandRun) -> Void) {
        self.present = present
    }

    func apply(_ newConfig: CommandsModuleConfig) {
        config = newConfig
        if newConfig.enabled, observer == nil {
            observer = DistributedNotificationCenter.default().addObserver(forName: CommandHook.notification, object: nil, queue: .main) { [weak self] notification in
                let info = notification.userInfo as? [String: String] ?? [:]
                MainActor.assumeIsolated { self?.handle(info) }
            }
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: CommandHook.cleanupInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.dropStale() }
            }
        } else if !newConfig.enabled, let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
            self.observer = nil
            cleanupTimer?.invalidate()
            cleanupTimer = nil
            history = []
            sessions = [:]
        }
        publish()
    }

    private func handle(_ info: [String: String]) {
        let session = info[CommandHook.Key.session] ?? ""
        let command = (info[CommandHook.Key.command] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !session.isEmpty, !command.isEmpty, !isIgnored(command) else {
            sessions[session] = nil
            publish()
            return
        }
        let cwd = info[CommandHook.Key.cwd] ?? ""
        let project = cwd.isEmpty ? "" : URL(fileURLWithPath: cwd).lastPathComponent
        let startedAt = info[CommandHook.Key.started].flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:)) ?? Date()
        let bundle = info[CommandHook.Key.bundle].flatMap { $0.isEmpty ? nil : $0 }
        let terminalSession = info[CommandHook.Key.terminalSession].flatMap { $0.isEmpty ? nil : $0 }

        switch info[CommandHook.Key.event] {
        case CommandHook.Event.start:
            sessions[session] = RunningCommand(session: session, command: command, project: project, startedAt: startedAt, bundleID: bundle, terminalSession: terminalSession)
            publish()
        case CommandHook.Event.end:
            sessions[session] = nil
            let now = Date()
            let duration = now.timeIntervalSince(startedAt)
            guard duration >= TimeInterval(config.minSeconds) else {
                publish()
                return
            }
            let outcome = CommandOutcome(exitCode: info[CommandHook.Key.exit].flatMap(Int.init) ?? 0)
            if outcome == .cancelled, !config.cancelled {
                publish()
                return
            }
            let run = CommandRun(command: command, project: project, outcome: outcome, duration: duration, finishedAt: now, bundleID: bundle, terminalSession: terminalSession)
            history.insert(run, at: 0)
            publish()
            if shouldPresent(run) { present(run) }
        default:
            return
        }
    }

    private func isIgnored(_ command: String) -> Bool {
        let program = CommandName.program(of: command)
        return program.isEmpty || config.ignored.contains(program)
    }

    private func shouldPresent(_ run: CommandRun) -> Bool {
        switch config.notify {
        case .always:
            return true
        case .failures:
            return run.outcome.isFailure
        case .away:
            guard let bundle = run.bundleID else { return true }
            return NSWorkspace.shared.frontmostApplication?.bundleIdentifier != bundle
        }
    }

    private func dropStale() {
        let now = Date()
        history = history.filter { now.timeIntervalSince($0.finishedAt) < CommandHook.staleAfter }
        sessions = sessions.filter { now.timeIntervalSince($0.value.startedAt) < CommandHook.runningStaleAfter }
        publish()
    }

    private func publish() {
        runs = history.sorted { lhs, rhs in
            if lhs.outcome.isFailure != rhs.outcome.isFailure { return lhs.outcome.isFailure }
            return lhs.finishedAt > rhs.finishedAt
        }
        running = sessions.values.sorted { $0.startedAt < $1.startedAt }
        updateStatus()
        if running.isEmpty {
            runningTimer?.invalidate()
            runningTimer = nil
        } else if runningTimer == nil {
            runningTimer = Timer.scheduledTimer(withTimeInterval: CommandHook.runningCheck, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.updateStatus() }
            }
        }
    }

    private func updateStatus() {
        guard config.enabled, config.showRunning else {
            if status != nil { status = nil }
            return
        }
        let limit = Date().addingTimeInterval(-TimeInterval(config.minSeconds))
        let visible = running.filter { $0.startedAt <= limit }
        let next = visible.first.map { oldest in
            RunningCommandStatus(startedAt: oldest.startedAt, count: visible.count)
        }
        if next != status { status = next }
    }
}
