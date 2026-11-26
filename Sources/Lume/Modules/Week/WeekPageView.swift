import SwiftUI

struct WeekPageView: View {
    @ObservedObject var store: WeekEventStore
    let showWeekend: Bool
    @State private var selectedDay: Date?

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            Group {
                if let day = selectedDay {
                    dayDetail(day, now: timeline.date)
                        .transition(.opacity.combined(with: .offset(y: 3)))
                } else {
                    overview(now: timeline.date)
                        .transition(.opacity.combined(with: .offset(y: 3)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: selectedDay)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { store.acceptsWeekScroll = selectedDay == nil }
        .onChange(of: selectedDay) { _, day in store.acceptsWeekScroll = day == nil }
        .onDisappear {
            store.acceptsWeekScroll = false
            store.showWeek(offset: 0)
        }
    }

    private var days: [Date] { store.days(includeWeekend: showWeekend) }

    private func overview(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(WeekText.weekTitle(offset: store.weekOffset)).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                Spacer(minLength: 0)
                if store.weekOffset != 0 {
                    Button { store.showWeek(offset: 0) } label: {
                        Text(WeekText.backToToday)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(NotchRim.amber)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(NotchRim.amber.opacity(0.18)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
                WeekNavButton(symbol: "chevron.left", label: WeekText.previousWeek) {
                    store.showWeek(offset: store.weekOffset - 1)
                }
                .disabled(store.weekOffset <= WeekModule.minOffset)
                Text(WeekText.range(days, calendar: store.calendar))
                    .font(.system(size: WeekLayout.metaSize))
                    .monospacedDigit()
                    .opacity(WeekLayout.secondaryOpacity)
                    .padding(.horizontal, 2)
                WeekNavButton(symbol: "chevron.right", label: WeekText.nextWeek) {
                    store.showWeek(offset: store.weekOffset + 1)
                }
                .disabled(store.weekOffset >= WeekModule.maxOffset)
            }
            .padding(.top, WeekLayout.headerTop - 2)

            switch store.state {
            case .ready:
                HStack(alignment: .top, spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Button { selectedDay = day } label: {
                            DayCell(day: day, now: now, isSelected: false, compact: false, store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, WeekLayout.stripTop)

                Group {
                    if store.weekOffset == 0 {
                        NextEventRow(event: store.nextEvent(after: now), now: now, calendar: store.calendar)
                    } else {
                        FirstEventRow(event: store.firstShownEvent, count: store.shownEvents.count, calendar: store.calendar)
                    }
                }
                .padding(.top, WeekLayout.nextRowTop)
            default:
                StatusMessage(state: store.state)
                    .padding(.top, WeekLayout.stripTop)
            }
        }
        .padding(.horizontal, WeekLayout.horizontalPadding)
    }

    private func dayDetail(_ day: Date, now: Date) -> some View {
        let dayEvents = store.events(on: day)
        let isToday = store.calendar.isDate(day, inSameDayAs: now)
        return VStack(alignment: .leading, spacing: WeekLayout.detailHeaderGap) {
                HStack(spacing: 8) {
                    Button { selectedDay = nil } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                            Text(isToday ? WeekText.today : WeekText.dayTitle(day, calendar: store.calendar))
                                .font(.system(size: WeekLayout.titleSize, weight: .semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(WeekText.backLabel)

                    Text(WeekText.count(dayEvents.count))
                        .font(.system(size: WeekLayout.metaSize))
                        .opacity(WeekLayout.secondaryOpacity)
                }
                .padding(.top, WeekLayout.detailHeaderTop)

            HStack(alignment: .top, spacing: WeekLayout.detailSpacing) {
                Group {
                    if dayEvents.isEmpty {
                        Text(WeekText.empty)
                            .font(.system(size: WeekLayout.rowSize))
                            .opacity(WeekLayout.secondaryOpacity)
                            .frame(height: WeekLayout.rowHeight)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: WeekLayout.rowSpacing) {
                                ForEach(dayEvents) { event in
                                    EventRow(event: event, isPast: isToday && event.end <= now, isNow: !event.isAllDay && event.start <= now && event.end > now, calendar: store.calendar)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: WeekLayout.listHeight, alignment: .topLeading)
                .frame(height: WeekLayout.listHeight)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(days, id: \.self) { other in
                        Button { selectedDay = other } label: {
                            DayCell(day: other, now: now, isSelected: store.calendar.isDate(other, inSameDayAs: day), compact: true, store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, WeekLayout.miniVerticalPadding)
                .frame(width: WeekLayout.miniWidth)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(WeekLayout.cardOpacity)))
            }
        }
        .padding(.horizontal, WeekLayout.horizontalPadding)
    }
}

private struct DayCell: View {
    let day: Date
    let now: Date
    let isSelected: Bool
    let compact: Bool
    @ObservedObject var store: WeekEventStore

    var body: some View {
        let calendar = store.calendar
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let isPast = !isToday && day < now
        let colors = Array(Set(store.events(on: day).map(\.color)).prefix(WeekLayout.maxDots))
        let circle = compact ? WeekLayout.miniCircle : WeekLayout.circle

        VStack(spacing: compact ? 2 : 3) {
            Text(WeekText.letter(day, calendar: calendar, compact: compact))
                .font(.system(size: compact ? WeekLayout.miniLetterSize : 9, weight: .semibold))
                .textCase(.uppercase)
                .opacity(0.45)
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: compact ? WeekLayout.miniNumberSize : 11.5, weight: isToday ? .bold : .medium))
                .monospacedDigit()
                .opacity(isPast ? 0.45 : 1)
                .frame(width: circle, height: circle)
                .background(Circle().fill(isToday ? NotchRim.coral : (isSelected ? .white.opacity(0.16) : .clear)))
                .overlay(Circle().stroke(.white.opacity(isSelected && !isToday ? 0.35 : 0), lineWidth: 1))
            dots(colors, vertical: compact)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 3)
        .contentShape(Rectangle())
        .accessibilityLabel(WeekText.dayTitle(day, calendar: calendar))
    }

    @ViewBuilder
    private func dots(_ colors: [Color], vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2.5))
        layout {
            ForEach(colors.indices, id: \.self) { index in
                Circle().fill(colors[index]).frame(width: WeekLayout.dot, height: WeekLayout.dot)
            }
        }
        .frame(height: vertical ? WeekLayout.verticalDotsHeight : WeekLayout.dot, alignment: .top)
    }
}

private struct EventRow: View {
    let event: CalendarEvent
    let isPast: Bool
    let isNow: Bool
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5).fill(event.color).frame(width: 3, height: 12)
            Text(isNow ? MeetingText.now : (event.isAllDay ? WeekText.allDay : WeekText.time(event.start, calendar: calendar)))
                .font(.system(size: WeekLayout.rowSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isNow ? MeetingLayout.live : .white)
                .opacity(isNow ? 1 : WeekLayout.secondaryOpacity)
            Text(event.title)
                .font(.system(size: WeekLayout.rowSize))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: WeekLayout.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.07)))
        .opacity(isPast ? 0.45 : 1)
    }
}

private struct NextEventRow: View {
    let event: CalendarEvent?
    let now: Date
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 8) {
            if let event {
                RoundedRectangle(cornerRadius: 1.5).fill(event.color).frame(width: 3, height: 12)
                Text(WeekText.next).opacity(WeekLayout.secondaryOpacity)
                Text(WeekText.time(event.start, calendar: calendar)).fontWeight(.semibold).monospacedDigit()
                Text(event.title).lineLimit(1)
                Spacer(minLength: 0)
                Text(WeekText.relative(from: now, to: event.start, calendar: calendar))
                    .opacity(0.5)
                    .lineLimit(1)
            } else {
                Text(WeekText.nothingLeft).opacity(WeekLayout.secondaryOpacity)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: WeekLayout.rowSize))
        .padding(.horizontal, 8)
        .frame(height: WeekLayout.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7).fill(NotchRim.coral.opacity(event == nil ? 0.06 : 0.12)))
    }
}

private struct FirstEventRow: View {
    let event: CalendarEvent?
    let count: Int
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 8) {
            if let event {
                RoundedRectangle(cornerRadius: 1.5).fill(event.color).frame(width: 3, height: 12)
                Text(WeekText.first).opacity(WeekLayout.secondaryOpacity)
                Text(event.isAllDay ? WeekText.letter(event.start, calendar: calendar, compact: false) : WeekText.dayAndTime(event.start, calendar: calendar))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(event.title).lineLimit(1)
                Spacer(minLength: 0)
                Text(WeekText.count(count)).opacity(0.5).lineLimit(1)
            } else {
                Text(WeekText.nothingThatWeek).opacity(WeekLayout.secondaryOpacity)
                Spacer(minLength: 0)
            }
        }
        .font(.system(size: WeekLayout.rowSize))
        .padding(.horizontal, 8)
        .frame(height: WeekLayout.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.07)))
    }
}

private struct WeekNavButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: WeekModule.navGlyph, weight: .bold))
                .frame(width: WeekModule.navButtonSize, height: WeekModule.navButtonSize)
                .background(Circle().fill(.white.opacity(0.12)))
                .contentShape(Circle())
                .opacity(isEnabled ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct StatusMessage: View {
    let state: WeekLoadState

    var body: some View {
        Text(text)
            .font(.system(size: WeekLayout.rowSize))
            .opacity(WeekLayout.secondaryOpacity)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: String {
        switch state {
        case .loading: WeekText.loading
        case .denied: WeekText.denied
        case .failed(let message): WeekText.failed + " " + message
        case .ready: ""
        }
    }
}
