import Foundation

enum WeeklyForecaster {
    static func forecast(window: LimitWindow?, now: Date = Date()) -> WeeklyForecast? {
        guard let window, let reset = window.resetsAt, reset > now else { return nil }
        let used = window.utilization
        let start = reset.addingTimeInterval(-UsageConfig.weekLength)
        let elapsedDays = now.timeIntervalSince(start) / 86_400
        guard elapsedDays >= UsageConfig.forecastMinElapsedDays else { return nil }
        let remainingDays = reset.timeIntervalSince(now) / 86_400
        let rate = used / elapsedDays
        let projected = min(used + rate * remainingDays, 100)

        let outcome: WeeklyForecast.Outcome
        if used >= 100 {
            outcome = .atLimit
        } else if rate > 0, (100 - used) / rate < remainingDays {
            outcome = .hits(now.addingTimeInterval((100 - used) / rate * 86_400))
        } else {
            outcome = .closes(projected)
        }

        return WeeklyForecast(
            usedPercent: used,
            projectedPercent: projected,
            ratePerDay: rate,
            resetsAt: reset,
            outcome: outcome
        )
    }
}
