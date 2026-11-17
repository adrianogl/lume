import EventKit

@MainActor
final class AgendaProvider {
    private let model: NotchModel
    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var alertedMeetings = Set<String>()
    private var joinedMeetings = Set<String>()
    private var isAwaitingJoin = false

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else {
                model.update(AgendaConfig.noAccess)
                return
            }

            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            refresh()

            refreshTask = Task {
                while !Task.isCancelled {
                    let delay = isAwaitingJoin ? AgendaConfig.joinCheckInterval : AgendaConfig.refreshInterval
                    try? await Task.sleep(for: .seconds(delay))
                    refresh()
                }
            }
        }
    }

    private func refresh() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) else { return }

        let today = events(from: startOfToday, to: startOfTomorrow)
        let tomorrow = events(from: startOfTomorrow, to: endOfTomorrow)
        detectJoinedMeetings(today, now: now)
        model.update(AgendaBuilder.category(today: today, tomorrowCount: tomorrow.count, joined: joinedMeetings, now: now, calendar: calendar))
        alertUpcomingMeetings(today, now: now)
    }

    private func detectJoinedMeetings(_ events: [AgendaEvent], now: Date) {
        let pending = events.filter {
            !$0.isAllDay && $0.joinURL != nil && $0.start <= now && $0.end > now && !joinedMeetings.contains($0.id)
        }
        if !pending.isEmpty, MicrophoneActivity.isCapturedByAnotherApp() {
            joinedMeetings.formUnion(pending.map(\.id))
        }
        isAwaitingJoin = events.contains {
            !$0.isAllDay && $0.joinURL != nil && $0.start <= now && $0.end > now && !joinedMeetings.contains($0.id)
        }
    }

    private func alertUpcomingMeetings(_ events: [AgendaEvent], now: Date) {
        for event in events where !event.isAllDay && !alertedMeetings.contains(event.id) {
            let secondsUntil = event.start.timeIntervalSince(now)
            guard secondsUntil > 0, secondsUntil <= AgendaConfig.meetingAlertWindow else { continue }
            alertedMeetings.insert(event.id)
            let minutes = max(Int((secondsUntil / 60).rounded(.up)), 1)
            model.present(NotchAlert(
                kind: .meeting,
                title: "\(event.title) em \(minutes) min",
                subtitle: "\(AgendaBuilder.place(of: event)) · \(AgendaBuilder.clock(event.start))–\(AgendaBuilder.clock(event.end))",
                actionTitle: event.joinURL == nil ? nil : "Entrar",
                actionURL: event.joinURL
            ))
        }
    }

    private func events(from start: Date, to end: Date) -> [AgendaEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            AgendaEvent(
                id: (event.eventIdentifier ?? event.title ?? "") + "|" + String(event.startDate.timeIntervalSince1970),
                title: event.title ?? "Sem título",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendarName: event.calendar?.title ?? "",
                location: event.location,
                joinURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
            )
        }
    }
}
