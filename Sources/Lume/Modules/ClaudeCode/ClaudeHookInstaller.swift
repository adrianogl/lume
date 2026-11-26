import Foundation

enum ClaudeHookInstaller {
    static func accounts() -> [ClaudeAccount] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let names = (try? FileManager.default.contentsOfDirectory(atPath: home.path)) ?? []
        return names
            .filter { $0 == ClaudeHook.directoryPrefix || $0.hasPrefix(ClaudeHook.directoryPrefix + "-") }
            .map { ClaudeAccount(directory: home.appendingPathComponent($0)) }
            .filter {
                FileManager.default.fileExists(atPath: $0.settingsFile.path)
                    && FileManager.default.fileExists(atPath: $0.directory.appendingPathComponent(ClaudeHook.projectsFolder).path)
            }
            .sorted { $0.directory.lastPathComponent < $1.directory.lastPathComponent }
    }

    static func isInstalled(in account: ClaudeAccount) -> Bool {
        guard let hooks = settings(of: account)?["hooks"] as? [String: Any] else { return false }
        return ClaudeHook.events.allSatisfy { event in
            (hooks[event] as? [[String: Any]] ?? []).contains(where: isLumeEntry)
        }
    }

    static func install(in account: ClaudeAccount, executable: String) throws {
        var root = settings(of: account) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let command = "'\(executable)' \(ClaudeHook.command) \(ClaudeHook.accountFlag) '\(account.directory.path)'"
        for event in ClaudeHook.events {
            var entries = (hooks[event] as? [[String: Any]] ?? []).filter { !isLumeEntry($0) }
            entries.append(["hooks": [["type": "command", "command": command]]])
            hooks[event] = entries
        }
        root["hooks"] = hooks
        try write(root, to: account)
    }

    static func remove(from account: ClaudeAccount) throws {
        guard var root = settings(of: account), var hooks = root["hooks"] as? [String: Any] else { return }
        for event in ClaudeHook.events {
            guard let entries = hooks[event] as? [[String: Any]] else { continue }
            let kept = entries.filter { !isLumeEntry($0) }
            hooks[event] = kept.isEmpty ? nil : kept
        }
        root["hooks"] = hooks
        try write(root, to: account)
    }

    private static func isLumeEntry(_ entry: [String: Any]) -> Bool {
        let commands = (entry["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
        return commands.contains { $0.contains(ClaudeHook.executableMarker) && $0.contains(ClaudeHook.command) }
    }

    private static func settings(of account: ClaudeAccount) -> [String: Any]? {
        guard let data = try? Data(contentsOf: account.settingsFile) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func write(_ root: [String: Any], to account: ClaudeAccount) throws {
        let file = account.settingsFile
        let backup = file.appendingPathExtension(ClaudeHook.backupExtension)
        if FileManager.default.fileExists(atPath: file.path), !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: file, to: backup)
        }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }
}
