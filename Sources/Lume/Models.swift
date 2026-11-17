import Foundation

enum Trend {
    case up, down, neutral
}

enum VoiceState {
    case idle, listening, processing, unavailable
}

struct LiveEvent {
    let start: Date
    let end: Date
}

struct NotchAlert: Identifiable, Equatable {
    enum Kind {
        case failure, success, info, meeting, attention
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var actionURL: URL? = nil
}

struct AgendaEvent {
    var id: String = ""
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarName: String
    let location: String?
    var joinURL: URL? = nil
}

struct NowPlaying: Equatable {
    let title: String
    let artist: String
    let isPlaying: Bool
    let appName: String
    var artworkURL: URL? = nil
}

struct MusicSource {
    let appName: String
    let bundleID: String
    let notificationName: String
}

enum MusicCommand: String {
    case playPause = "playpause"
    case next = "next track"
    case previous = "previous track"
}

struct VoiceExchange {
    let heard: String
    var reply: String? = nil
}

struct StatTile: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var trend: Trend = .neutral
}

struct ContentRow: Identifiable {
    let id = UUID()
    var time: String? = nil
    var checked: Bool? = nil
    let title: String
    var detail: String? = nil
    var trailing: String? = nil
    var trend: Trend = .neutral
    var actionURL: URL? = nil
    var actionTitle: String? = nil
}

struct LumeCategory: Identifiable {
    let id: String
    let name: String
    let symbol: String
    var badge: Int? = nil
    var earLead: String? = nil
    var live: LiveEvent? = nil
    var joinURL: URL? = nil
    let earText: String
    let title: String
    var subtitle: String
    var tiles: [StatTile] = []
    var rows: [ContentRow] = []
    var bars: [WeekBar] = []
}

struct WeekBar: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let isToday: Bool
}

struct BrainReply {
    let text: String
    var categoryID: String? = nil
}

struct AlertRecord: Identifiable {
    let id = UUID()
    let date: Date
    let alert: NotchAlert
}
