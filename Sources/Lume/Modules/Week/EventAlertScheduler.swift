import Foundation

@MainActor
final class EventAlertScheduler {
    private let store: WeekEventStore
    private let present: (EventAlert) -> Void
    private var config = WeekModuleConfig()
    private var timer: Timer?
    private var fired: Set<String> = []

    init(store: WeekEventStore, present: @escaping (EventAlert) -> Void) {
        self.store = store
        self.present = present
    }

    func apply(_ newConfig: WeekModuleConfig) {
        config = newConfig
        let wantsAlerts = newConfig.enabled && (!newConfig.alerts.minutesBefore.isEmpty || newConfig.alerts.atStart)
        if wantsAlerts, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: AlertLayout.checkInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.check() }
            }
            check()
        } else if !wantsAlerts {
            timer?.invalidate()
            timer = nil
        }
    }

    private func check() {
        let now = Date()
        var leads = Set(config.alerts.minutesBefore.filter { $0 > 0 })
        if config.alerts.atStart { leads.insert(0) }

        for event in store.events where !event.isAllDay {
            for lead in leads.sorted(by: >) {
                let fireAt = event.start.addingTimeInterval(-TimeInterval(lead * 60))
                guard now >= fireAt, now < fireAt.addingTimeInterval(AlertLayout.firingWindow) else { continue }
                let alert = EventAlert(event: event, leadMinutes: lead)
                guard !fired.contains(alert.id) else { continue }
                fired.insert(alert.id)
                present(alert)
            }
        }
        fired = fired.filter { key in store.events.contains { key.hasPrefix($0.id + "|") } }
    }
}
