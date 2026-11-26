import Foundation

@MainActor
final class MeetingTracker {
    private let store: WeekEventStore
    private let publish: (MeetingStatus?) -> Void
    private var config = WeekModuleConfig()
    private var timer: Timer?

    init(store: WeekEventStore, publish: @escaping (MeetingStatus?) -> Void) {
        self.store = store
        self.publish = publish
    }

    func apply(_ newConfig: WeekModuleConfig) {
        config = newConfig
        let active = newConfig.enabled && newConfig.duringEvent.enabled
        if active, timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: MeetingLayout.refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.update() }
            }
        } else if !active {
            timer?.invalidate()
            timer = nil
        }
        update()
    }

    func update() {
        guard config.enabled, config.duringEvent.enabled else {
            publish(nil)
            return
        }
        let now = Date()
        let current = store.events
            .filter { !$0.isAllDay && $0.start <= now && $0.end > now }
            .min { $0.end < $1.end }
        guard let current else {
            publish(nil)
            return
        }
        let remaining = Int((current.end.timeIntervalSince(now) / 60).rounded(.up))
        let isEnding = config.duringEvent.endingMinutes > 0 && remaining <= config.duringEvent.endingMinutes
        let next = store.events.first {
            !$0.isAllDay && $0.id != current.id && $0.start >= current.end.addingTimeInterval(-60)
                && $0.start <= current.end.addingTimeInterval(MeetingLayout.nextWindow)
        }
        publish(MeetingStatus(event: current, remainingMinutes: max(remaining, 1), isEnding: isEnding, next: isEnding ? next : nil))
    }
}
