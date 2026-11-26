import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case clock, week, music, claudeCode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: NotchPage.clock.title
        case .week: NotchPage.week.title
        case .music: NotchPage.music.title
        case .claudeCode: SettingsText.claudeTitle
        }
    }

    var symbol: String {
        switch self {
        case .clock: NotchPage.clock.symbol
        case .week: NotchPage.week.symbol
        case .music: NotchPage.music.symbol
        case .claudeCode: "terminal"
        }
    }

    func isEnabled(in config: LumeConfig) -> Bool {
        switch self {
        case .clock: config.modules.clock.enabled
        case .week: config.modules.week.enabled
        case .music: config.modules.music.enabled
        case .claudeCode: config.modules.claudeCode.enabled
        }
    }
}
