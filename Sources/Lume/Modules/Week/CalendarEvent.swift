import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    var joinURL: URL? = nil
}

struct EventAlert: Identifiable, Equatable {
    let event: CalendarEvent
    let leadMinutes: Int

    var id: String { "\(event.id)|\(leadMinutes)" }
    var isStart: Bool { leadMinutes == 0 }
}

struct CalendarChoice: Identifiable, Equatable {
    let title: String
    let color: Color

    var id: String { title }
}

enum WeekLoadState: Equatable {
    case loading
    case ready
    case denied
    case failed(String)
}
