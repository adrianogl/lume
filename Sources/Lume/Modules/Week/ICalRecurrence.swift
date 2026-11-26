import Foundation

struct RecurrenceRule: Equatable {
    enum Frequency: String {
        case daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY"
    }

    struct Weekday: Equatable {
        let weekday: Int
        let ordinal: Int?
    }

    let frequency: Frequency
    let interval: Int
    let count: Int?
    let until: Date?
    let byDay: [Weekday]
    let byMonthDay: [Int]

    private static let weekdays = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]

    init?(_ text: String, parseDate: (String) -> Date?) {
        var parts: [String: String] = [:]
        for pair in text.split(separator: ";") {
            let item = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if item.count == 2 { parts[item[0].uppercased()] = item[1] }
        }
        guard let frequency = parts["FREQ"].flatMap(Frequency.init(rawValue:)) else { return nil }
        self.frequency = frequency
        interval = max(parts["INTERVAL"].flatMap(Int.init) ?? 1, 1)
        count = parts["COUNT"].flatMap(Int.init)
        until = parts["UNTIL"].flatMap(parseDate)
        byDay = (parts["BYDAY"] ?? "").split(separator: ",").compactMap { token in
            let code = String(token.suffix(2))
            guard let weekday = Self.weekdays[code] else { return nil }
            let prefix = token.dropLast(2)
            return Weekday(weekday: weekday, ordinal: prefix.isEmpty ? nil : Int(prefix))
        }
        byMonthDay = (parts["BYMONTHDAY"] ?? "").split(separator: ",").compactMap { Int($0) }
    }
}

enum ICalRecurrence {
    static let iterationLimit = 20_000

    static func starts(of start: Date, rule: RecurrenceRule, timeZone: TimeZone, until limit: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        let end = min(rule.until ?? limit, limit)
        var result: [Date] = []
        var produced = 0
        var step = 0

        while step < iterationLimit, let anchor = anchor(at: step, from: start, rule: rule, calendar: calendar), anchor <= end {
            for candidate in candidates(in: anchor, start: start, rule: rule, calendar: calendar) where candidate >= start {
                if let count = rule.count, produced >= count { return result }
                if let until = rule.until, candidate > until { return result }
                produced += 1
                if candidate <= limit { result.append(candidate) }
            }
            step += 1
        }
        return result
    }

    private static func anchor(at step: Int, from start: Date, rule: RecurrenceRule, calendar: Calendar) -> Date? {
        let amount = step * rule.interval
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: amount, to: start)
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start
            return weekStart.flatMap { calendar.date(byAdding: .weekOfYear, value: amount, to: $0) }
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: start)?.start
            return monthStart.flatMap { calendar.date(byAdding: .month, value: amount, to: $0) }
        case .yearly:
            return calendar.date(byAdding: .year, value: amount, to: start)
        }
    }

    private static func candidates(in anchor: Date, start: Date, rule: RecurrenceRule, calendar: Calendar) -> [Date] {
        let time = calendar.dateComponents([.hour, .minute, .second], from: start)
        func at(_ day: Date) -> Date? {
            calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day)
        }

        switch rule.frequency {
        case .daily:
            guard !rule.byDay.isEmpty else { return [anchor] }
            let weekday = calendar.component(.weekday, from: anchor)
            return rule.byDay.contains { $0.weekday == weekday } ? [anchor] : []
        case .weekly:
            let weekdays = rule.byDay.isEmpty ? [calendar.component(.weekday, from: start)] : rule.byDay.map(\.weekday)
            return (0..<7).compactMap { offset -> Date? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: anchor),
                      weekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
                return at(day)
            }
        case .monthly:
            guard let range = calendar.range(of: .day, in: .month, for: anchor) else { return [] }
            let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: anchor) }
            if !rule.byDay.isEmpty {
                return days.filter { day in
                    rule.byDay.contains { matches($0, day: day, in: days, calendar: calendar) }
                }.compactMap(at)
            }
            let monthDays = rule.byMonthDay.isEmpty ? [calendar.component(.day, from: start)] : rule.byMonthDay
            return monthDays.compactMap { value -> Date? in
                let index = value > 0 ? value - 1 : days.count + value
                return days.indices.contains(index) ? at(days[index]) : nil
            }.sorted()
        case .yearly:
            return [anchor]
        }
    }

    private static func matches(_ rule: RecurrenceRule.Weekday, day: Date, in days: [Date], calendar: Calendar) -> Bool {
        guard calendar.component(.weekday, from: day) == rule.weekday else { return false }
        guard let ordinal = rule.ordinal else { return true }
        let same = days.filter { calendar.component(.weekday, from: $0) == rule.weekday }
        guard let position = same.firstIndex(of: day) else { return false }
        return ordinal > 0 ? position == ordinal - 1 : position == same.count + ordinal
    }
}
