import Foundation

enum DemoAlert {
    static func make() -> EventAlert {
        let event = CalendarEvent(
            id: "demo",
            title: ProcessInfo.processInfo.environment["LUME_DEMO_TITLE"] ?? "Daily standup",
            start: Date().addingTimeInterval(5 * 60),
            end: Date().addingTimeInterval(20 * 60),
            isAllDay: false,
            color: NotchRim.coral,
            joinURL: URL(string: "https://teams.microsoft.com/l/meetup-join/demo")
        )
        return EventAlert(event: event, leadMinutes: 5)
    }
}

enum DemoMeeting {
    static func make(ending: Bool) -> MeetingStatus {
        let now = Date()
        let event = CalendarEvent(
            id: "demo-meeting",
            title: "Daily standup",
            start: now.addingTimeInterval(-10 * 60),
            end: now.addingTimeInterval(ending ? 4 * 60 : 12 * 60),
            isAllDay: false,
            color: NotchRim.coral
        )
        let next = CalendarEvent(
            id: "demo-next",
            title: "1:1 com o tech lead",
            start: now.addingTimeInterval(5 * 60),
            end: now.addingTimeInterval(35 * 60),
            isAllDay: false,
            color: NotchRim.coral
        )
        return MeetingStatus(event: event, remainingMinutes: ending ? 4 : 12, isEnding: ending, next: ending ? next : nil)
    }
}
