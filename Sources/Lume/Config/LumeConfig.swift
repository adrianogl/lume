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
    var music = MusicModuleConfig()
    var claudeCode = ClaudeCodeModuleConfig()
    var pullRequests = PullRequestsModuleConfig()
    var claudeUsage = ClaudeUsageModuleConfig()
    var commands = CommandsModuleConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = try container.decodeIfPresent(ClockModuleConfig.self, forKey: .clock) ?? ClockModuleConfig()
        week = try container.decodeIfPresent(WeekModuleConfig.self, forKey: .week) ?? WeekModuleConfig()
        music = try container.decodeIfPresent(MusicModuleConfig.self, forKey: .music) ?? MusicModuleConfig()
        claudeCode = try container.decodeIfPresent(ClaudeCodeModuleConfig.self, forKey: .claudeCode) ?? ClaudeCodeModuleConfig()
        pullRequests = try container.decodeIfPresent(PullRequestsModuleConfig.self, forKey: .pullRequests) ?? PullRequestsModuleConfig()
        claudeUsage = try container.decodeIfPresent(ClaudeUsageModuleConfig.self, forKey: .claudeUsage) ?? ClaudeUsageModuleConfig()
        commands = try container.decodeIfPresent(CommandsModuleConfig.self, forKey: .commands) ?? CommandsModuleConfig()
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
    var duringEvent = DuringEventConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        source = try container.decodeIfPresent(CalendarSource.self, forKey: .source) ?? .eventKit
        calendars = try container.decodeIfPresent([String].self, forKey: .calendars) ?? []
        weekStartsOn = try container.decodeIfPresent(WeekStart.self, forKey: .weekStartsOn) ?? .monday
        showWeekend = try container.decodeIfPresent(Bool.self, forKey: .showWeekend) ?? true
        alerts = try container.decodeIfPresent(EventAlertsConfig.self, forKey: .alerts) ?? EventAlertsConfig()
        duringEvent = try container.decodeIfPresent(DuringEventConfig.self, forKey: .duringEvent) ?? DuringEventConfig()
    }
}

struct DuringEventConfig: Codable, Equatable {
    var enabled = true
    var endingMinutes = 5

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        endingMinutes = try container.decodeIfPresent(Int.self, forKey: .endingMinutes) ?? 5
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

struct MusicModuleConfig: Codable, Equatable {
    var enabled = true
    var showWhilePlaying = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        showWhilePlaying = try container.decodeIfPresent(Bool.self, forKey: .showWhilePlaying) ?? true
    }
}

struct ClaudeCodeModuleConfig: Codable, Equatable {
    var enabled = true
    var permission = true
    var waiting = true
    var finished = true
    var accountNames: [String: String] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        permission = try container.decodeIfPresent(Bool.self, forKey: .permission) ?? true
        waiting = try container.decodeIfPresent(Bool.self, forKey: .waiting) ?? true
        finished = try container.decodeIfPresent(Bool.self, forKey: .finished) ?? true
        accountNames = try container.decodeIfPresent([String: String].self, forKey: .accountNames) ?? [:]
    }
}

struct PullRequestsModuleConfig: Codable, Equatable {
    var enabled = true
    var pollMinutes = 2
    var includeDrafts = false
    var includeBots = false
    var organizations: [String] = []
    var alerts = PullRequestAlertsConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        pollMinutes = try container.decodeIfPresent(Int.self, forKey: .pollMinutes) ?? 2
        includeDrafts = try container.decodeIfPresent(Bool.self, forKey: .includeDrafts) ?? false
        includeBots = try container.decodeIfPresent(Bool.self, forKey: .includeBots) ?? false
        organizations = try container.decodeIfPresent([String].self, forKey: .organizations) ?? []
        alerts = try container.decodeIfPresent(PullRequestAlertsConfig.self, forKey: .alerts) ?? PullRequestAlertsConfig()
    }
}

struct PullRequestAlertsConfig: Codable, Equatable {
    var reviewRequested = true
    var ciFailed = true
    var changesRequested = true
    var approved = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reviewRequested = try container.decodeIfPresent(Bool.self, forKey: .reviewRequested) ?? true
        ciFailed = try container.decodeIfPresent(Bool.self, forKey: .ciFailed) ?? true
        changesRequested = try container.decodeIfPresent(Bool.self, forKey: .changesRequested) ?? true
        approved = try container.decodeIfPresent(Bool.self, forKey: .approved) ?? true
    }

    func allows(_ state: PRState) -> Bool {
        switch state {
        case .reviewRequested: reviewRequested
        case .ciFailed: ciFailed
        case .changesRequested: changesRequested
        case .approved, .readyToMerge: approved
        case .conflict, .waiting, .draft: false
        }
    }
}

struct ClaudeUsageModuleConfig: Codable, Equatable {
    var enabled = true
    var showWhenClosed = true
    var alertThresholds = [80, 95]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        showWhenClosed = try container.decodeIfPresent(Bool.self, forKey: .showWhenClosed) ?? true
        alertThresholds = try container.decodeIfPresent([Int].self, forKey: .alertThresholds) ?? [80, 95]
    }
}

struct CommandsModuleConfig: Codable, Equatable {
    var enabled = true
    var minSeconds = 30
    var notify = CommandNotifyMode.away
    var cancelled = false
    var showRunning = true
    var ignored = CommandHook.defaultIgnored

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        minSeconds = try container.decodeIfPresent(Int.self, forKey: .minSeconds) ?? 30
        notify = try container.decodeIfPresent(CommandNotifyMode.self, forKey: .notify) ?? .away
        cancelled = try container.decodeIfPresent(Bool.self, forKey: .cancelled) ?? false
        showRunning = try container.decodeIfPresent(Bool.self, forKey: .showRunning) ?? true
        ignored = try container.decodeIfPresent([String].self, forKey: .ignored) ?? CommandHook.defaultIgnored
    }
}
