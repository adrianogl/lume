import EventKit
import SwiftUI

@MainActor
final class WeekEventStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var state = WeekLoadState.loading
    @Published private(set) var weekStart = Date()
    @Published private(set) var availableCalendars: [CalendarChoice] = []

    private let eventStore = EKEventStore()
    private var config = WeekModuleConfig()
    private var timer: Timer?
    private var storeObserver: Any?
    private var isRunning = false

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: OpenLayout.localeID)
        calendar.firstWeekday = config.weekStartsOn == .monday ? 2 : 1
        return calendar
    }

    func apply(_ newConfig: WeekModuleConfig) {
        let changed = newConfig != config
        config = newConfig
        if !newConfig.enabled {
            stop()
            return
        }
        if !isRunning {
            start()
        } else if changed {
            refresh()
        }
    }

    private func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: WeekModule.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        storeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        if let storeObserver { NotificationCenter.default.removeObserver(storeObserver) }
        storeObserver = nil
        events = []
    }

    func refresh() {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
        weekStart = interval.start
        switch config.source {
        case .eventKit:
            Task { await loadFromEventKit(interval) }
        case .ical(let url):
            Task { await loadFromICal(url, interval: interval) }
        }
    }

    private func loadFromEventKit(_ interval: DateInterval) async {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            let granted = (try? await eventStore.requestFullAccessToEvents()) ?? false
            guard granted else { state = .denied; return }
        } else if status != .fullAccess {
            state = .denied
            return
        }

        availableCalendars = eventStore.calendars(for: .event)
            .map { CalendarChoice(title: $0.title, color: Color(cgColor: $0.cgColor)) }
            .reduce(into: [CalendarChoice]()) { result, choice in
                if !result.contains(where: { $0.title == choice.title }) { result.append(choice) }
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let calendars = eventStore.calendars(for: .event).filter {
            config.calendars.isEmpty || config.calendars.contains($0.title)
        }
        guard !calendars.isEmpty else {
            events = []
            state = .ready
            return
        }
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        events = eventStore.events(matching: predicate)
            .map {
                CalendarEvent(
                    id: $0.calendarItemIdentifier + "\($0.startDate.timeIntervalSince1970)",
                    title: $0.title ?? "",
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    color: Color(cgColor: $0.calendar.cgColor)
                )
            }
            .sorted { $0.start < $1.start }
        state = .ready
    }

    private func loadFromICal(_ url: URL, interval: DateInterval) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(decoding: data, as: UTF8.self)
            events = ICalParser.events(from: text)
                .filter { $0.end > interval.start && $0.start < interval.end }
                .map {
                    CalendarEvent(id: $0.uid, title: $0.summary, start: $0.start, end: $0.end, isAllDay: $0.isAllDay, color: NotchRim.coral)
                }
                .sorted { $0.start < $1.start }
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func days(includeWeekend: Bool) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .filter { includeWeekend || !calendar.isDateInWeekend($0) }
    }

    func events(on day: Date) -> [CalendarEvent] {
        guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else { return [] }
        let start = calendar.startOfDay(for: day)
        return events.filter { $0.start < next && $0.end > start }
    }

    func nextEvent(after date: Date) -> CalendarEvent? {
        events.first { !$0.isAllDay && $0.start > date }
    }
}
