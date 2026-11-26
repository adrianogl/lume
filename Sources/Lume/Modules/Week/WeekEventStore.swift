import EventKit
import SwiftUI

@MainActor
final class WeekEventStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var state = WeekLoadState.loading
    @Published private(set) var weekStart = Date()
    @Published private(set) var availableCalendars: [CalendarChoice] = []
    @Published private(set) var weekOffset = 0
    @Published private(set) var shownWeekStart = Date()
    @Published private(set) var shownEvents: [CalendarEvent] = []

    private let eventStore = EKEventStore()
    private var config = WeekModuleConfig()
    private var timer: Timer?
    private var storeObserver: Any?
    private var isRunning = false
    private var icalText: String?
    var acceptsWeekScroll = false

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
        shownEvents = []
        weekOffset = 0
    }

    func refresh() {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
        weekStart = interval.start
        Task { await load(interval) }
    }

    func showWeek(offset: Int) {
        let clamped = min(max(offset, WeekModule.minOffset), WeekModule.maxOffset)
        guard clamped != weekOffset else { return }
        weekOffset = clamped
        reloadShown()
    }

    private func load(_ interval: DateInterval) async {
        switch config.source {
        case .eventKit:
            guard await authorize() else { state = .denied; return }
            updateAvailableCalendars()
            events = eventKitEvents(in: interval)
        case .ical(let url):
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                icalText = String(decoding: data, as: UTF8.self)
                events = icalEvents(in: interval)
            } catch {
                state = .failed(error.localizedDescription)
                return
            }
        }
        state = .ready
        reloadShown()
    }

    private func reloadShown() {
        guard weekOffset != 0, let start = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart),
              let interval = calendar.dateInterval(of: .weekOfYear, for: start) else {
            shownWeekStart = weekStart
            shownEvents = events
            return
        }
        shownWeekStart = interval.start
        switch config.source {
        case .eventKit: shownEvents = eventKitEvents(in: interval)
        case .ical: shownEvents = icalEvents(in: interval)
        }
    }

    private func authorize() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .notDetermined {
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        }
        return status == .fullAccess
    }

    private func updateAvailableCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .map { CalendarChoice(title: $0.title, color: Color(cgColor: $0.cgColor)) }
            .reduce(into: [CalendarChoice]()) { result, choice in
                if !result.contains(where: { $0.title == choice.title }) { result.append(choice) }
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func eventKitEvents(in interval: DateInterval) -> [CalendarEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let calendars = eventStore.calendars(for: .event).filter {
            config.calendars.isEmpty || config.calendars.contains($0.title)
        }
        guard !calendars.isEmpty else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return eventStore.events(matching: predicate)
            .map {
                CalendarEvent(
                    id: $0.calendarItemIdentifier + "\($0.startDate.timeIntervalSince1970)",
                    title: $0.title ?? "",
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    color: Color(cgColor: $0.calendar.cgColor),
                    joinURL: MeetingLink.find(in: [$0.url?.absoluteString, $0.location, $0.notes])
                )
            }
            .sorted { $0.start < $1.start }
    }

    private func icalEvents(in interval: DateInterval) -> [CalendarEvent] {
        guard let icalText else { return [] }
        return ICalParser.occurrences(from: icalText, in: interval)
            .map {
                CalendarEvent(id: $0.uid, title: $0.summary, start: $0.start, end: $0.end, isAllDay: $0.isAllDay, color: NotchRim.coral, joinURL: MeetingLink.find(in: $0.linkTexts))
            }
            .sorted { $0.start < $1.start }
    }

    func days(includeWeekend: Bool) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: shownWeekStart) }
            .filter { includeWeekend || !calendar.isDateInWeekend($0) }
    }

    func events(on day: Date) -> [CalendarEvent] {
        guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else { return [] }
        let start = calendar.startOfDay(for: day)
        return shownEvents.filter { $0.start < next && $0.end > start }
    }

    func nextEvent(after date: Date) -> CalendarEvent? {
        events.first { !$0.isAllDay && $0.start > date }
    }

    var firstShownEvent: CalendarEvent? {
        shownEvents.first { !$0.isAllDay } ?? shownEvents.first
    }
}
