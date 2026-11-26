import Foundation

enum NotchPage: String, CaseIterable {
    case clock, week

    var title: String {
        switch self {
        case .clock: "Relógio"
        case .week: "Semana"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .week: "calendar"
        }
    }

    static func enabled(in config: LumeConfig) -> [NotchPage] {
        allCases.filter { page in
            switch page {
            case .clock: config.modules.clock.enabled
            case .week: config.modules.week.enabled
            }
        }
    }
}
