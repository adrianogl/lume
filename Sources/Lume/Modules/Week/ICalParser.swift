import Foundation

enum ICalParser {
    struct RawEvent {
        let uid: String
        let summary: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let linkTexts: [String?]
        var rule: RecurrenceRule? = nil
        var exdates: Set<Date> = []
        var recurrenceID: Date? = nil
        var timeZone: TimeZone = .current
    }

    static func occurrences(from text: String, in interval: DateInterval) -> [RawEvent] {
        let all = events(from: text)
        let overrides = Set(all.compactMap { event in event.recurrenceID.map { "\(event.uid)|\($0.timeIntervalSince1970)" } })
        var result: [RawEvent] = []
        for event in all {
            guard let rule = event.rule, event.recurrenceID == nil else {
                if event.end > interval.start, event.start < interval.end { result.append(event) }
                continue
            }
            let duration = event.end.timeIntervalSince(event.start)
            let starts = ICalRecurrence.starts(of: event.start, rule: rule, timeZone: event.timeZone, until: interval.end)
            for start in starts where start.addingTimeInterval(duration) > interval.start && start < interval.end {
                guard !event.exdates.contains(start), !overrides.contains("\(event.uid)|\(start.timeIntervalSince1970)") else { continue }
                result.append(RawEvent(
                    uid: event.uid + "|\(Int(start.timeIntervalSince1970))",
                    summary: event.summary,
                    start: start,
                    end: start.addingTimeInterval(duration),
                    isAllDay: event.isAllDay,
                    linkTexts: event.linkTexts
                ))
            }
        }
        return result
    }

    static func events(from text: String) -> [RawEvent] {
        var events: [RawEvent] = []
        var fields: [String: (params: [String: String], value: String)] = [:]
        var exdates: Set<Date> = []
        var inEvent = false

        for line in unfold(text) {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                fields = [:]
                exdates = []
                continue
            }
            if line == "END:VEVENT" {
                inEvent = false
                if var event = makeEvent(fields) {
                    event.exdates = exdates
                    events.append(event)
                }
                continue
            }
            guard inEvent, let colon = line.firstIndex(of: ":") else { continue }
            let head = line[..<colon].split(separator: ";").map(String.init)
            guard let name = head.first?.uppercased() else { continue }
            var params: [String: String] = [:]
            for pair in head.dropFirst() {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 { params[parts[0].uppercased()] = parts[1] }
            }
            let value = String(line[line.index(after: colon)...])
            if name == "EXDATE" {
                for item in value.split(separator: ",") {
                    if let date = date(String(item), params: params) { exdates.insert(date) }
                }
            } else {
                fields[name] = (params, value)
            }
        }
        return events
    }

    private static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    private static func makeEvent(_ fields: [String: (params: [String: String], value: String)]) -> RawEvent? {
        guard let startField = fields["DTSTART"], let start = date(startField.value, params: startField.params) else { return nil }
        let isAllDay = startField.params["VALUE"] == "DATE" || startField.value.count == 8
        let end = fields["DTEND"].flatMap { date($0.value, params: $0.params) }
            ?? start.addingTimeInterval(isAllDay ? 86_400 : 3_600)
        var event = RawEvent(
            uid: fields["UID"]?.value ?? UUID().uuidString,
            summary: unescape(fields["SUMMARY"]?.value ?? ""),
            start: start,
            end: end,
            isAllDay: isAllDay,
            linkTexts: [fields["URL"]?.value, fields["LOCATION"].map { unescape($0.value) }, fields["DESCRIPTION"].map { unescape($0.value) }]
        )
        event.timeZone = startField.params["TZID"].flatMap(TimeZone.init(identifier:)) ?? .current
        event.rule = fields["RRULE"].flatMap { RecurrenceRule($0.value, parseDate: { date($0, params: [:]) }) }
        event.recurrenceID = fields["RECURRENCE-ID"].flatMap { date($0.value, params: $0.params) }
        return event
    }

    private static func date(_ value: String, params: [String: String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if value.count == 8 {
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = .current
        } else if value.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
        } else {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            formatter.timeZone = params["TZID"].flatMap(TimeZone.init(identifier:)) ?? .current
        }
        return formatter.date(from: value)
    }

    private static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
