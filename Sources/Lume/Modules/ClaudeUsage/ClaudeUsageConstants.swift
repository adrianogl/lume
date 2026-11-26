import SwiftUI

enum UsageLayout {
    static let openSize = CGSize(width: 460, height: 250)
    static let refresh: TimeInterval = 30
    static let barHeight: CGFloat = 5
    static let barGap: CGFloat = 14
    static let blockPadding: CGFloat = 7
    static let nameSize: CGFloat = 11.5
    static let labelSize: CGFloat = 9.5
    static let tagSize: CGFloat = 8
    static let symbol = "gauge.with.dots.needle.67percent"
    static let symbolSize: CGFloat = 11
    static let percentSize: CGFloat = 10.5
    static let percentWidth: CGFloat = 22
    static let calmLimit = 50
    static let warmLimit = 80
    static let hotLimit = 95
    static let dimOpacity: Double = 0.5
    static let activeWindow: TimeInterval = 120
    static let staleAfter: TimeInterval = 3_600
    static let alertIconSize: CGFloat = 30
    static let alertGlyphSize: CGFloat = 15
}

enum UsageStatusLine {
    static let command = "statusline"
    static let thenFlag = "--then"
    static let folder = "usage"
    static let notification = Notification.Name("local.lume.claude-usage")
    static let shell = "/bin/sh"
    static let thresholdChoices = [50, 80, 90, 95]
}

enum UsageText {
    static let title = "Uso do Claude"
    static let fiveHour = "5 horas"
    static let week = "Semana"
    static let inUse = "em uso"
    static let alreadyReset = "já zerou"
    static let empty = "Sem leitura ainda. Instale na status line em Ajustes › Uso do Claude e abra uma sessão."
    static let close = "Fechar"
    static let closedLabel = "Uso do Claude perto do limite"

    static func resets(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        "zera " + moment(date, now: now, calendar: calendar)
    }

    static func moment(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "pt_BR")))
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "amanhã \(time)"
        }
        let weekday = date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "pt_BR")))
            .replacingOccurrences(of: ".", with: "")
        return "\(weekday) \(time)"
    }

    static func updated(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "há \(minutes) min" }
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "há \(minutes / 60) h" }
        return moment(date, now: now)
    }

    static func until(_ date: Date, now: Date) -> String {
        let minutes = max(Int(date.timeIntervalSince(now) / 60), 0)
        if minutes < 60 { return "daqui a \(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 { return rest == 0 ? "daqui a \(hours) h" : "daqui a \(hours) h \(rest) min" }
        return "daqui a \(hours / 24) d"
    }

    static func alertTitle(account: String, threshold: Int, window: UsageWindowKind) -> String {
        "\(account) passou de \(threshold)% \(window == .fiveHour ? "das 5 horas" : "da semana")"
    }

    static func alertSubtitle(resetsAt: Date, now: Date) -> String {
        "Zera \(moment(resetsAt, now: now)), \(until(resetsAt, now: now))"
    }

    static func percent(_ value: Int) -> String { "\(value)%" }
}
