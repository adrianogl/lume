import Foundation

enum AgendaBuilder {
    static func category(today: [AgendaEvent], tomorrowCount: Int, joined: Set<String> = [], now: Date, calendar: Calendar = .current) -> LumeCategory {
        let timed = today.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        let allDay = today.filter(\.isAllDay)
        let upcoming = timed.filter { $0.end > now }
        let current = upcoming.first { $0.start <= now }
        let next = upcoming.first { $0.start > now }

        var rows = allDay.map { ContentRow(time: "Dia", title: $0.title, detail: $0.calendarName) }
        rows += upcoming.map { row(for: $0, joined: joined, now: now) }
        if rows.isEmpty {
            rows = [ContentRow(
                title: timed.isEmpty ? "Nenhum evento hoje" : "Nada mais hoje",
                detail: tomorrowCount > 0 ? "Amanhã: \(eventCount(tomorrowCount))" : nil
            )]
        }

        return LumeCategory(
            id: AgendaConfig.categoryID,
            name: "Agenda",
            symbol: "calendar",
            badge: upcoming.isEmpty ? nil : upcoming.count,
            earLead: earLead(current: current, next: next, now: now),
            live: current.map { LiveEvent(start: $0.start, end: $0.end) },
            joinURL: (current ?? next).flatMap { isJoinable($0, now: now) && !joined.contains($0.id) ? $0.joinURL : nil },
            earText: earText(current: current, next: next, hadEvents: !timed.isEmpty),
            title: "Hoje",
            subtitle: subtitle(total: today.count, next: next, now: now),
            tiles: [
                StatTile(label: "Livre hoje", value: duration(freeTime(events: timed, now: now, calendar: calendar))),
                StatTile(label: "Em eventos", value: duration(busyTime(events: timed))),
                StatTile(label: "Amanhã", value: "\(tomorrowCount)")
            ],
            rows: Array(rows.prefix(AgendaConfig.maxRows))
        )
    }

    private static func row(for event: AgendaEvent, joined: Set<String>, now: Date) -> ContentRow {
        let place = event.location.flatMap { $0.isEmpty ? nil : $0 } ?? event.calendarName
        let length = duration(event.end.timeIntervalSince(event.start))
        return ContentRow(
            time: event.start <= now ? "Agora" : clock(event.start),
            title: event.title,
            detail: "\(place) · \(length)",
            actionURL: isJoinable(event, now: now) && !joined.contains(event.id) ? event.joinURL : nil
        )
    }

    static func isJoinable(_ event: AgendaEvent, now: Date) -> Bool {
        event.joinURL != nil && event.end > now && event.start.timeIntervalSince(now) <= AgendaConfig.joinWindow
    }

    static func place(of event: AgendaEvent) -> String {
        event.location.flatMap { $0.isEmpty ? nil : $0 } ?? event.calendarName
    }

    private static func earLead(current: AgendaEvent?, next: AgendaEvent?, now: Date) -> String? {
        guard current == nil, let next else { return nil }
        let minutes = minutesUntil(next.start, now: now)
        return minutes < 60 ? "em \(minutes) min" : clock(next.start)
    }

    private static func earText(current: AgendaEvent?, next: AgendaEvent?, hadEvents: Bool) -> String {
        if let current { return current.title }
        if let next { return next.title }
        return hadEvents ? "Nada mais hoje" : "Agenda livre hoje"
    }

    private static func minutesUntil(_ date: Date, now: Date) -> Int {
        max(Int((date.timeIntervalSince(now) / 60).rounded(.up)), 1)
    }

    private static func subtitle(total: Int, next: AgendaEvent?, now: Date) -> String {
        guard total > 0 else { return "sem eventos" }
        guard let next else { return eventCount(total) }
        return "\(eventCount(total)) · próximo \(relative(next.start, now: now))"
    }

    private static func relative(_ date: Date, now: Date) -> String {
        let minutes = minutesUntil(date, now: now)
        return minutes < 60 ? "em \(minutes) min" : "às \(clock(date))"
    }

    private static func eventCount(_ count: Int) -> String {
        count == 1 ? "1 evento" : "\(count) eventos"
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: VoiceConfig.localeID)
        formatter.dateFormat = AgendaConfig.timeFormat
        return formatter.string(from: date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(Int(seconds / 60), 0)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) h" }
        return "\(hours)h" + String(format: "%02d", rest)
    }

    private static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.sorted { $0.start < $1.start }.reduce(into: [DateInterval]()) { result, interval in
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
    }

    private static func busyTime(events: [AgendaEvent]) -> TimeInterval {
        merged(events.map { DateInterval(start: $0.start, end: max($0.start, $0.end)) })
            .reduce(0) { $0 + $1.duration }
    }

    private static func freeTime(events: [AgendaEvent], now: Date, calendar: Calendar) -> TimeInterval {
        guard let dayStart = calendar.date(bySettingHour: AgendaConfig.workdayStartHour, minute: 0, second: 0, of: now),
              let dayEnd = calendar.date(bySettingHour: AgendaConfig.workdayEndHour, minute: 0, second: 0, of: now) else { return 0 }
        let windowStart = max(now, dayStart)
        guard windowStart < dayEnd else { return 0 }

        let busy = merged(events.compactMap { event in
            let start = max(event.start, windowStart)
            let end = min(event.end, dayEnd)
            return start < end ? DateInterval(start: start, end: end) : nil
        })
        return dayEnd.timeIntervalSince(windowStart) - busy.reduce(0) { $0 + $1.duration }
    }
}
