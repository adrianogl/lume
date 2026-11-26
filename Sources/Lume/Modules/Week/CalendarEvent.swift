import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
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
