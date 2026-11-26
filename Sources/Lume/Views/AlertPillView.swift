import AppKit
import SwiftUI

struct AlertPillView: View {
    let alert: NotchAlert
    let isBlinking: Bool
    let dismiss: () -> Void
    let onContentHeight: (CGFloat) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: AlertLayout.textRefresh)) { timeline in
            HStack(spacing: AlertLayout.spacing) {
                OwlMascot(width: AlertLayout.mascotWidth, isBlinking: isBlinking)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(.system(size: AlertLayout.titleSize, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if case .claude(let claude) = alert {
                            Text(claude.tag)
                                .font(.system(size: ClaudeLayout.tagSize, weight: .bold))
                                .textCase(.uppercase)
                                .foregroundStyle(claude.tagColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(RoundedRectangle(cornerRadius: 4).fill(claude.tagColor.opacity(0.16)))
                        }
                    }
                    Text(subtitle(now: timeline.date))
                        .font(.system(size: AlertLayout.subtitleSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                PillButton(title: secondaryTitle, isPrimary: false, action: dismiss)
                if let primary {
                    PillButton(title: primary.title, isPrimary: true) {
                        primary.action()
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

    private var title: String {
        switch alert {
        case .event(let event): event.event.title
        case .claude(let claude): claude.title
        }
    }

    private var secondaryTitle: String {
        switch alert {
        case .event(let event): event.isStart ? AlertText.close : AlertText.later
        case .claude: ClaudeText.later
        }
    }

    private var primary: (title: String, action: () -> Void)? {
        switch alert {
        case .event(let event):
            guard let url = event.event.joinURL else { return nil }
            return (AlertText.join, { NSWorkspace.shared.open(url) })
        case .claude(let claude):
            guard let bundle = claude.bundleID, !bundle.isEmpty else { return nil }
            return (ClaudeText.open, { ClaudeCodeMonitor.open(bundleID: bundle) })
        }
    }

    private func subtitle(now: Date) -> String {
        switch alert {
        case .claude(let claude):
            return claude.subtitle
        case .event(let event):
            let calendar = Calendar.current
            var parts: [String]
            if event.isStart || event.event.start <= now {
                parts = [AlertText.startedNow]
            } else {
                parts = [
                    WeekText.relative(from: now, to: event.event.start, calendar: calendar),
                    WeekText.time(event.event.start, calendar: calendar)
                ]
            }
            if let provider = event.event.joinURL.flatMap(MeetingLink.provider(of:)) {
                parts.append(provider)
            }
            return parts.joined(separator: " · ")
        }
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
