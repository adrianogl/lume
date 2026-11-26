import Foundation

enum NotchPage: String, CaseIterable {
    case clock, week, music

    var title: String {
        switch self {
        case .clock: "Relógio"
        case .week: "Semana"
        case .music: "Música"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .week: "calendar"
        case .music: "music.note"
        }
    }

    static func enabled(in config: LumeConfig) -> [NotchPage] {
        allCases.filter { page in
            switch page {
            case .clock: config.modules.clock.enabled
            case .week: config.modules.week.enabled
            case .music: config.modules.music.enabled
            }
        }
    }
}
