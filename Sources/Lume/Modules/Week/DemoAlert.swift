import Foundation

enum DemoAlert {
    static func make() -> EventAlert {
        let event = CalendarEvent(
            id: "demo",
            title: "Daily MEF",
            start: Date().addingTimeInterval(5 * 60),
            end: Date().addingTimeInterval(20 * 60),
            isAllDay: false,
            color: NotchRim.coral,
            joinURL: URL(string: "https://teams.microsoft.com/l/meetup-join/demo")
        )
        return EventAlert(event: event, leadMinutes: 5)
    }
}
