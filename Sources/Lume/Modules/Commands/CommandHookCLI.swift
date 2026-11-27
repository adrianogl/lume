import Foundation

enum CommandHookCLI {
    static func run(_ arguments: [String]) {
        let environment = ProcessInfo.processInfo.environment
        let info: [String: String] = [
            CommandHook.Key.event: value(after: CommandHook.Flag.event, in: arguments) ?? "",
            CommandHook.Key.exit: value(after: CommandHook.Flag.exit, in: arguments) ?? "",
            CommandHook.Key.started: value(after: CommandHook.Flag.started, in: arguments) ?? "",
            CommandHook.Key.command: String((value(after: CommandHook.Flag.command, in: arguments) ?? "").prefix(CommandHook.commandLimit)),
            CommandHook.Key.cwd: value(after: CommandHook.Flag.cwd, in: arguments) ?? "",
            CommandHook.Key.session: value(after: CommandHook.Flag.session, in: arguments) ?? "",
            CommandHook.Key.bundle: environment["__CFBundleIdentifier"] ?? "",
            CommandHook.Key.terminalSession: environment["ITERM_SESSION_ID"]
                .flatMap { $0.split(separator: ":").last.map(String.init) } ?? ""
        ]
        DistributedNotificationCenter.default().postNotificationName(
            CommandHook.notification,
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
