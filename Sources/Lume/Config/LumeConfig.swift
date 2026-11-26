import Foundation

struct LumeConfig: Codable, Equatable {
    var modules = ModulesConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modules = try container.decodeIfPresent(ModulesConfig.self, forKey: .modules) ?? ModulesConfig()
    }
}

struct ModulesConfig: Codable, Equatable {
    var clock = ClockModuleConfig()
    var week = WeekModuleConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = try container.decodeIfPresent(ClockModuleConfig.self, forKey: .clock) ?? ClockModuleConfig()
        week = try container.decodeIfPresent(WeekModuleConfig.self, forKey: .week) ?? WeekModuleConfig()
    }
}

struct ClockModuleConfig: Codable, Equatable {
    var enabled = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

struct WeekModuleConfig: Codable, Equatable {
    var enabled = true
    var source = CalendarSource.eventKit
    var calendars: [String] = []
    var weekStartsOn = WeekStart.monday
    var showWeekend = true
    var alerts = EventAlertsConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        source = try container.decodeIfPresent(CalendarSource.self, forKey: .source) ?? .eventKit
        calendars = try container.decodeIfPresent([String].self, forKey: .calendars) ?? []
        weekStartsOn = try container.decodeIfPresent(WeekStart.self, forKey: .weekStartsOn) ?? .monday
        showWeekend = try container.decodeIfPresent(Bool.self, forKey: .showWeekend) ?? true
        alerts = try container.decodeIfPresent(EventAlertsConfig.self, forKey: .alerts) ?? EventAlertsConfig()
    }
}

struct EventAlertsConfig: Codable, Equatable {
    var minutesBefore = [5]
    var atStart = true
    var shake = true
    var sound = AlertSound.defaultName

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minutesBefore = try container.decodeIfPresent([Int].self, forKey: .minutesBefore) ?? [5]
        atStart = try container.decodeIfPresent(Bool.self, forKey: .atStart) ?? true
        shake = try container.decodeIfPresent(Bool.self, forKey: .shake) ?? true
        sound = try container.decodeIfPresent(String.self, forKey: .sound) ?? AlertSound.defaultName
    }
}

enum WeekStart: String, Codable {
    case monday, sunday
}

enum CalendarSource: Codable, Equatable {
    case eventKit
    case ical(URL)

    private enum CodingKeys: String, CodingKey {
        case type, url
    }

    private enum Kind: String, Codable {
        case eventkit, ical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .eventkit:
            self = .eventKit
        case .ical:
            self = .ical(try container.decode(URL.self, forKey: .url))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .eventKit:
            try container.encode(Kind.eventkit, forKey: .type)
        case .ical(let url):
            try container.encode(Kind.ical, forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}
