import Foundation

enum WeekText {
    static let title = "Semana"
    static let today = "Hoje"
    static let next = "Próximo"
    static let nothingLeft = "Nada mais esta semana"
    static let empty = "Nada marcado"
    static let allDay = "Dia todo"
    static let loading = "Carregando a agenda…"
    static let denied = "Sem acesso ao Calendário. Libere em Ajustes do Sistema › Privacidade e Segurança › Calendários."
    static let failed = "Não consegui ler o calendário."
    static let backLabel = "Voltar para a semana"
    static let first = "Primeiro"
    static let backToToday = "Hoje"
    static let previousWeek = "Semana anterior"
    static let nextWeek = "Próxima semana"
    static let nothingThatWeek = "Nada marcado nesta semana"

    static func weekTitle(offset: Int) -> String {
        switch offset {
        case 0: title
        case 1: "Próxima semana"
        case -1: "Semana passada"
        case let value where value > 1: "Em \(value) semanas"
        default: "Há \(-offset) semanas"
        }
    }

    static func dayAndTime(_ date: Date, calendar: Calendar) -> String {
        letter(date, calendar: calendar, compact: false) + " " + time(date, calendar: calendar)
    }

    static func count(_ count: Int) -> String {
        count == 1 ? "1 evento" : "\(count) eventos"
    }

    static func letter(_ day: Date, calendar: Calendar, compact: Bool) -> String {
        let name = formatted(day, "EEE", calendar: calendar).replacingOccurrences(of: ".", with: "")
        return compact ? String(name.prefix(1)) : name
    }

    static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        formatted(day, "EEE, d MMM", calendar: calendar).replacingOccurrences(of: ".", with: "")
    }

    static func time(_ date: Date, calendar: Calendar) -> String {
        formatted(date, "HH:mm", calendar: calendar)
    }

    static func range(_ days: [Date], calendar: Calendar) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        let end = formatted(last, "d MMM", calendar: calendar).replacingOccurrences(of: ".", with: "")
        guard calendar.component(.month, from: first) == calendar.component(.month, from: last) else {
            return formatted(first, "d MMM", calendar: calendar).replacingOccurrences(of: ".", with: "") + " – " + end
        }
        return "\(calendar.component(.day, from: first)) – \(end)"
    }

    static func relative(from now: Date, to date: Date, calendar: Calendar) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if minutes < 60 { return "em \(max(minutes, 1)) min" }
        if calendar.isDate(date, inSameDayAs: now) {
            let rest = minutes % 60
            return rest == 0 ? "em \(minutes / 60)h" : "em \(minutes / 60)h \(rest)min"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "amanhã"
        }
        return letter(date, calendar: calendar, compact: false)
    }

    private static func formatted(_ date: Date, _ format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
