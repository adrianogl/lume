import SwiftUI

enum ClaudeEventKind: String {
    case permission, waiting, finished, resolved
}

struct ClaudeAlert: Identifiable, Equatable {
    let id = UUID()
    let kind: ClaudeEventKind
    let sessionID: String
    let project: String
    let account: String
    let message: String
    let bundleID: String?
    let terminalSession: String?
    let sessionTitle: String

    var title: String {
        switch kind {
        case .permission: ClaudeText.permissionTitle
        case .waiting: ClaudeText.waitingTitle
        default: ClaudeText.finishedTitle
        }
    }

    var tag: String {
        switch kind {
        case .permission: ClaudeText.permissionTag
        case .waiting: ClaudeText.waitingTag
        default: ClaudeText.finishedTag
        }
    }

    var tagColor: Color {
        switch kind {
        case .permission: NotchRim.amber
        case .waiting: .white
        default: MeetingLayout.live
        }
    }

    var subtitle: String {
        [project, account, message].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var detail: String {
        [account, message].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct ClaudeSessionEntry: Identifiable, Equatable {
    let alert: ClaudeAlert
    var isWaiting: Bool
    let updatedAt: Date

    var id: String { alert.sessionID }
}

struct ClaudeAccount: Identifiable, Equatable {
    let directory: URL
    var id: String { directory.path }

    var defaultName: String {
        let name = directory.lastPathComponent
        guard name.hasPrefix(ClaudeHook.directoryPrefix + "-") else { return ClaudeText.defaultAccount }
        return String(name.dropFirst(ClaudeHook.directoryPrefix.count + 1)).uppercased()
    }

    var settingsFile: URL { directory.appendingPathComponent(ClaudeHook.settingsFile) }
}

enum NotchAlert: Identifiable, Equatable {
    case event(EventAlert)
    case claude(ClaudeAlert)

    var id: String {
        switch self {
        case .event(let alert): alert.id
        case .claude(let alert): alert.id.uuidString
        }
    }
}
