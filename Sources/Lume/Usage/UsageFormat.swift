import Foundation

enum Format {
    static func tokens(_ value: Int) -> String {
        let v = Double(value)
        let text: String
        switch v {
        case 1_000_000_000...: text = String(format: "%.1f B", v / 1_000_000_000)
        case 1_000_000...: text = String(format: "%.1f M", v / 1_000_000)
        case 1_000...: text = String(format: "%.0f k", v / 1_000)
        default: text = "\(value)"
        }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE HH:mm"
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f
    }()

    static func reset(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        if seconds <= 0 { return "agora" }
        if seconds < 24 * 3600 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return String(format: "em %dh%02d", hours, minutes)
        }
        return weekday.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private static let forecastDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE HH'h'"
        return f
    }()

    static func forecast(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = String(format: "%02dh", calendar.component(.hour, from: date))
        if calendar.isDateInToday(date) { return "hoje " + hour }
        if calendar.isDateInTomorrow(date) { return "amanhã " + hour }
        return forecastDay.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    static func percentRate(_ value: Double) -> String {
        String(format: "%.1f%%/dia", value).replacingOccurrences(of: ".", with: ",")
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static func time(_ date: Date) -> String { clock.string(from: date) }

    static func dayLabel(_ date: Date) -> String { dayMonth.string(from: date) }

    private static let fullDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, dd/MM"
        return f
    }()

    static func fullDayLabel(_ date: Date) -> String {
        let text = fullDay.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static func hourLabel(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        return String(format: "Hoje, %02dh–%02dh", hour, hour + 1)
    }

    static func plan(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "atualizando…" }
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        return minutes < 1 ? "atualizado agora" : "atualizado há \(minutes) min"
    }
}
