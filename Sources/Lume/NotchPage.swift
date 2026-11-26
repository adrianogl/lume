import Foundation

enum NotchPage: String, CaseIterable {
    case clock, week, music, claudeCode, pullRequests

    var title: String {
        switch self {
        case .clock: "Relógio"
        case .week: "Semana"
        case .music: "Música"
        case .claudeCode: "Claude Code"
        case .pullRequests: PRText.title
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .week: "calendar"
        case .music: "music.note"
        case .claudeCode: "terminal"
        case .pullRequests: PRLayout.symbol
        }
    }

    var openSize: CGSize {
        switch self {
        case .claudeCode: ClaudeCard.openSize
        case .pullRequests: PRLayout.openSize
        default: NotchHover.openSize
        }
    }

    static func enabled(in config: LumeConfig) -> [NotchPage] {
        allCases.filter { page in
            switch page {
            case .clock: config.modules.clock.enabled
            case .week: config.modules.week.enabled
            case .music: config.modules.music.enabled
            case .claudeCode: config.modules.claudeCode.enabled
            case .pullRequests: config.modules.pullRequests.enabled
            }
        }
    }
}
