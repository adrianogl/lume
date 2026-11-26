import Foundation

enum ICalParser {
    struct RawEvent {
        let uid: String
        let summary: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let linkTexts: [String?]
    }

    static func events(from text: String) -> [RawEvent] {
        var events: [RawEvent] = []
        var fields: [String: (params: [String: String], value: String)] = [:]
        var inEvent = false

        for line in unfold(text) {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                fields = [:]
                continue
            }
            if line == "END:VEVENT" {
                inEvent = false
                if let event = makeEvent(fields) { events.append(event) }
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
            fields[name] = (params, String(line[line.index(after: colon)...]))
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
        return RawEvent(
            uid: fields["UID"]?.value ?? UUID().uuidString,
            summary: unescape(fields["SUMMARY"]?.value ?? ""),
            start: start,
            end: end,
            isAllDay: isAllDay,
            linkTexts: [fields["URL"]?.value, fields["LOCATION"].map { unescape($0.value) }, fields["DESCRIPTION"].map { unescape($0.value) }]
        )
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
