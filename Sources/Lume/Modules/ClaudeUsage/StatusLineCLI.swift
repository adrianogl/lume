import Foundation

enum StatusLineCLI {
    static func run(_ arguments: [String]) {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let account = value(after: ClaudeHook.accountFlag, in: arguments)
            ?? ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(ClaudeHook.directoryPrefix).path

        if let snapshot = snapshot(from: input, account: account), (try? UsageStore.save(snapshot)) != nil {
            DistributedNotificationCenter.default().postNotificationName(
                UsageStatusLine.notification,
                object: nil,
                userInfo: [ClaudeHook.Key.account: account],
                deliverImmediately: true
            )
        }

        if let command = value(after: UsageStatusLine.thenFlag, in: arguments), !command.isEmpty {
            forward(input, to: command)
        }
    }

    static func snapshot(from data: Data, account: String) -> UsageSnapshot? {
        guard
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let limits = payload["rate_limits"] as? [String: Any]
        else { return nil }
        let fiveHour = window(limits["five_hour"])
        let sevenDay = window(limits["seven_day"])
        guard fiveHour != nil || sevenDay != nil else { return nil }
        return UsageSnapshot(account: account, fiveHour: fiveHour, sevenDay: sevenDay, updatedAt: Date())
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard
            let object = value as? [String: Any],
            let used = (object["used_percentage"] as? NSNumber)?.doubleValue,
            let resets = (object["resets_at"] as? NSNumber)?.doubleValue
        else { return nil }
        return UsageWindow(usedPercentage: Int(used.rounded()), resetsAt: Date(timeIntervalSince1970: resets))
    }

    private static func forward(_ input: Data, to command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: UsageStatusLine.shell)
        process.arguments = ["-c", command]
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        guard (try? process.run()) != nil else { return }
        stdin.fileHandleForWriting.write(input)
        try? stdin.fileHandleForWriting.close()
        process.waitUntilExit()
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

enum StatusLineInstaller {
    static func isInstalled(in account: ClaudeAccount) -> Bool {
        currentCommand(of: account).map(isLumeCommand) ?? false
    }

    static func install(in account: ClaudeAccount, executable: String) throws {
        var root = settings(of: account) ?? [:]
        var statusLine = root["statusLine"] as? [String: Any] ?? ["type": "command"]
        let existing = statusLine["command"] as? String
        guard existing.map(isLumeCommand) != true else { return }
        var command = "\(quote(executable)) \(UsageStatusLine.command) \(ClaudeHook.accountFlag) \(quote(account.directory.path))"
        if let existing, !existing.isEmpty {
            command += " \(UsageStatusLine.thenFlag) \(quote(existing))"
        }
        statusLine["type"] = "command"
        statusLine["command"] = command
        root["statusLine"] = statusLine
        try ClaudeSettingsFile.write(root, to: account)
    }

    static func remove(from account: ClaudeAccount) throws {
        guard var root = settings(of: account), var statusLine = root["statusLine"] as? [String: Any],
              let command = statusLine["command"] as? String, isLumeCommand(command) else { return }
        if let original = original(in: command) {
            statusLine["command"] = original
            root["statusLine"] = statusLine
        } else {
            root["statusLine"] = nil
        }
        try ClaudeSettingsFile.write(root, to: account)
    }

    static func original(in command: String) -> String? {
        let marker = " \(UsageStatusLine.thenFlag) '"
        guard let range = command.range(of: marker), command.hasSuffix("'") else { return nil }
        let quoted = command[range.upperBound..<command.index(before: command.endIndex)]
        return quoted.replacingOccurrences(of: "'\\''", with: "'")
    }

    private static func isLumeCommand(_ command: String) -> Bool {
        command.contains(ClaudeHook.executableMarker) && command.contains(" \(UsageStatusLine.command) \(ClaudeHook.accountFlag) ")
    }

    private static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func currentCommand(of account: ClaudeAccount) -> String? {
        (settings(of: account)?["statusLine"] as? [String: Any])?["command"] as? String
    }

    private static func settings(of account: ClaudeAccount) -> [String: Any]? {
        ClaudeSettingsFile.read(account)
    }
}
