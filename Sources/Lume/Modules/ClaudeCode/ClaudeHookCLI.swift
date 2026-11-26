import Foundation

enum ClaudeHookCLI {
    static func run(_ arguments: [String]) {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard let payload = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] else { return }

        let event = payload["hook_event_name"] as? String ?? ""
        let message = payload["message"] as? String ?? ""
        let kind = kind(for: event, message: message, type: payload["notification_type"] as? String)
        let account = value(after: ClaudeHook.accountFlag, in: arguments)
            ?? ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(ClaudeHook.directoryPrefix).path

        var text = message
        var title = ""
        if kind != .resolved, let transcript = payload["transcript_path"] as? String {
            title = sessionTitle(transcriptPath: transcript) ?? ""
            if kind == .finished {
                text = lastAssistantText(transcriptPath: transcript) ?? ""
            }
        }

        let info: [String: String] = [
            ClaudeHook.Key.kind: kind.rawValue,
            ClaudeHook.Key.session: payload["session_id"] as? String ?? "",
            ClaudeHook.Key.cwd: payload["cwd"] as? String ?? "",
            ClaudeHook.Key.message: String(text.prefix(ClaudeHook.messageLimit)),
            ClaudeHook.Key.title: title,
            ClaudeHook.Key.account: account,
            ClaudeHook.Key.bundle: ProcessInfo.processInfo.environment["__CFBundleIdentifier"] ?? "",
            ClaudeHook.Key.terminalSession: ProcessInfo.processInfo.environment["ITERM_SESSION_ID"]
                .flatMap { $0.split(separator: ":").last.map(String.init) } ?? ""
        ]
        DistributedNotificationCenter.default().postNotificationName(
            ClaudeHook.notification,
            object: nil,
            userInfo: info,
            deliverImmediately: true
        )
    }

    private static func kind(for event: String, message: String, type: String?) -> ClaudeEventKind {
        switch event {
        case "Stop":
            return .finished
        case "Notification":
            if type == "permission_prompt" || message.localizedCaseInsensitiveContains("permission") {
                return .permission
            }
            return .waiting
        default:
            return .resolved
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func sessionTitle(transcriptPath: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: transcriptPath), options: .alwaysMapped) else { return nil }
        for key in ClaudeHook.titleKeys {
            let marker = Data("\"\(key)\":\"".utf8)
            guard let range = data.range(of: marker, options: .backwards) else { continue }
            if let value = jsonString(in: data, from: range.upperBound), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func jsonString(in data: Data, from start: Data.Index) -> String? {
        var index = start
        var escaped = false
        while index < data.endIndex {
            let byte = data[index]
            if escaped {
                escaped = false
            } else if byte == UInt8(ascii: "\\") {
                escaped = true
            } else if byte == UInt8(ascii: "\"") {
                let quoted = Data("\"".utf8) + data[start..<index] + Data("\"".utf8)
                return try? JSONDecoder().decode(String.self, from: quoted)
            }
            index = data.index(after: index)
        }
        return nil
    }

    private static func lastAssistantText(transcriptPath: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: transcriptPath) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > ClaudeHook.transcriptTail ? size - ClaudeHook.transcriptTail : 0
        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n").reversed() {
            guard let json = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let message = json["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { continue }
            let texts = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
            if let first = texts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
                return first.replacingOccurrences(of: "\n", with: " ")
            }
        }
        return nil
    }
}
