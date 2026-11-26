import AppKit
import SwiftUI

struct AlertPillView: View {
    let alert: EventAlert
    let isBlinking: Bool
    let dismiss: () -> Void
    let onContentHeight: (CGFloat) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: AlertLayout.textRefresh)) { timeline in
            HStack(spacing: AlertLayout.spacing) {
                OwlMascot(width: AlertLayout.mascotWidth, isBlinking: isBlinking)

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.event.title)
                        .font(.system(size: AlertLayout.titleSize, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle(now: timeline.date))
                        .font(.system(size: AlertLayout.subtitleSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                PillButton(title: alert.isStart ? AlertText.close : AlertText.later, isPrimary: false, action: dismiss)
                if let url = alert.event.joinURL {
                    PillButton(title: AlertText.join, isPrimary: true) {
                        NSWorkspace.shared.open(url)
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, AlertLayout.horizontalPadding)
            .padding(.vertical, AlertLayout.verticalPadding)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: AlertContentHeightKey.self, value: proxy.size.height)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onPreferenceChange(AlertContentHeightKey.self, perform: onContentHeight)
    }

    private func subtitle(now: Date) -> String {
        let calendar = Calendar.current
        var parts: [String]
        if alert.isStart || alert.event.start <= now {
            parts = [AlertText.startedNow]
        } else {
            parts = [
                WeekText.relative(from: now, to: alert.event.start, calendar: calendar),
                WeekText.time(alert.event.start, calendar: calendar)
            ]
        }
        if let provider = alert.event.joinURL.flatMap(MeetingLink.provider(of:)) {
            parts.append(provider)
        }
        return parts.joined(separator: " · ")
    }
}

private struct AlertContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PillButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: AlertLayout.buttonFontSize, weight: isPrimary ? .bold : .semibold))
                .foregroundStyle(isPrimary ? Color.black : Color.white)
                .padding(.horizontal, 11)
                .frame(height: AlertLayout.buttonHeight)
                .background(Capsule().fill(isPrimary ? Color.white : Color.white.opacity(0.14)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
