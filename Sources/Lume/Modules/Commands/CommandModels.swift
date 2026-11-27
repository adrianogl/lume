import SwiftUI

enum CommandOutcome: Equatable {
    case ok, failed(Int), cancelled

    init(exitCode: Int) {
        switch exitCode {
        case 0: self = .ok
        case CommandHook.cancelledExit: self = .cancelled
        default: self = .failed(exitCode)
        }
    }

    var tag: String {
        switch self {
        case .ok: CommandText.okTag
        case .failed(let code): CommandText.exitTag(code)
        case .cancelled: CommandText.cancelledTag
        }
    }

    var verb: String {
        switch self {
        case .ok: CommandText.finished
        case .failed: CommandText.failed
        case .cancelled: CommandText.cancelled
        }
    }

    var color: Color {
        switch self {
        case .ok: CommandLayout.ok
        case .failed: CommandLayout.failed
        case .cancelled: CommandLayout.cancelled
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark"
        case .failed: "xmark"
        case .cancelled: "stop.fill"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

struct CommandRun: Identifiable, Equatable {
    let id = UUID()
    let command: String
    let project: String
    let outcome: CommandOutcome
    let duration: TimeInterval
    let finishedAt: Date
    let bundleID: String?
    let terminalSession: String?

    var title: String {
        CommandText.shortened(command, to: CommandLayout.titleLength) + " " + outcome.verb
    }

    var subtitle: String {
        [project, CommandText.duration(duration)].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct RunningCommand: Identifiable, Equatable {
    let session: String
    let command: String
    let project: String
    let startedAt: Date
    let bundleID: String?
    let terminalSession: String?

    var id: String { session }
}

struct RunningCommandStatus: Equatable {
    let startedAt: Date
    let count: Int
}

enum CommandNotifyMode: String, Codable, CaseIterable {
    case away, always, failures
}

enum CommandName {
    static func program(of command: String) -> String {
        let words = command.split(whereSeparator: \.isWhitespace).map(String.init)
        let program = words.first { word in
            !CommandHook.wrappers.contains(word) && !word.hasPrefix("-") && !isAssignment(word)
        }
        return program.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
    }

    private static func isAssignment(_ word: String) -> Bool {
        guard let equals = word.firstIndex(of: "=") else { return false }
        return !word[..<equals].isEmpty && word[..<equals].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
