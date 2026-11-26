import SwiftUI

struct ClaudeCardView: View {
    @ObservedObject var monitor: ClaudeCodeMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: ClaudeCard.refresh)) { timeline in
            VStack(alignment: .leading, spacing: ClaudeCard.rowSpacing) {
                HStack(spacing: 6) {
                    ClaudeMark()
                        .fill(ClaudeLayout.markColor)
                        .frame(width: ClaudeLayout.markSize, height: ClaudeLayout.markSize)
                    Text(ClaudeText.cardTitle).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(ClaudeText.waitingCount(monitor.pendingCount))
                        .font(.system(size: WeekLayout.metaSize, weight: monitor.pendingCount > 0 ? .semibold : .regular))
                        .foregroundStyle(monitor.pendingCount > 0 ? NotchRim.amber : .white.opacity(WeekLayout.secondaryOpacity))
                }
                .padding(.top, WeekLayout.headerTop)
                .padding(.bottom, 2)

                if monitor.entries.isEmpty {
                    Text(ClaudeText.cardEmpty)
                        .font(.system(size: WeekLayout.rowSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .padding(.top, 12)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: ClaudeCard.rowSpacing) {
                            ForEach(monitor.entries) { entry in
                                ClaudeRow(entry: entry, now: timeline.date)
                            }
                        }
                    }
                    .frame(height: ClaudeCard.listHeight)
                }
            }
            .padding(.horizontal, WeekLayout.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ClaudeRow: View {
    let entry: ClaudeSessionEntry
    let now: Date

    var body: some View {
        let alert = entry.alert
        HStack(spacing: 7) {
            Text(alert.tag)
                .font(.system(size: ClaudeLayout.tagSize, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(alert.tagColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(alert.tagColor.opacity(0.16)))
            Text(alert.project).font(.system(size: ClaudeCard.textSize, weight: .semibold)).lineLimit(1).layoutPriority(1)
            Text(alert.detail)
                .font(.system(size: ClaudeCard.textSize))
                .opacity(WeekLayout.secondaryOpacity)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ClaudeText.ago(from: entry.updatedAt, to: now))
                .font(.system(size: 10))
                .monospacedDigit()
                .opacity(0.4)
            if let bundle = alert.bundleID, !bundle.isEmpty {
                Button {
                    ClaudeCodeMonitor.open(bundleID: bundle, terminalSession: alert.terminalSession)
                } label: {
                    Text(ClaudeText.open)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(entry.isWaiting ? Color.black : Color.white)
                        .padding(.horizontal, 8)
                        .frame(height: 17)
                        .background(Capsule().fill(entry.isWaiting ? Color.white : Color.white.opacity(0.14)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: ClaudeCard.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(entry.isWaiting ? 0.07 : 0.035)))
        .opacity(entry.isWaiting ? 1 : 0.6)
    }
}
