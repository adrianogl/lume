import SwiftUI

struct ClaudeUsageCardView: View {
    @ObservedObject var monitor: ClaudeUsageMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: UsageLayout.refresh)) { timeline in
            let now = timeline.date
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: UsageLayout.symbol)
                        .font(.system(size: UsageLayout.symbolSize, weight: .semibold))
                    Text(UsageText.title).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                    Spacer(minLength: 0)
                    if let latest = monitor.entries.first {
                        Text(UsageText.updated(latest.snapshot.updatedAt, now: now))
                            .font(.system(size: UsageLayout.labelSize + 1))
                            .opacity(0.45)
                    }
                }
                .padding(.top, WeekLayout.headerTop)
                .padding(.bottom, 4)

                if monitor.entries.isEmpty {
                    Text(UsageText.empty)
                        .font(.system(size: WeekLayout.rowSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(monitor.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    Rectangle().fill(.white.opacity(PRLayout.dividerOpacity)).frame(height: 1)
                                }
                                UsageBlock(entry: entry, now: now)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, WeekLayout.horizontalPadding)
            .padding(.bottom, OpenLayout.dotsBottom + 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct UsageBlock: View {
    let entry: UsageEntry
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(entry.name).font(.system(size: UsageLayout.nameSize, weight: .semibold))
                if entry.isActive(at: now) {
                    Text(UsageText.inUse)
                        .font(.system(size: UsageLayout.tagSize, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.12)))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                Text(UsageText.updated(entry.snapshot.updatedAt, now: now))
                    .font(.system(size: UsageLayout.labelSize))
                    .opacity(0.4)
            }
            HStack(spacing: UsageLayout.barGap) {
                UsageBar(title: UsageText.fiveHour, window: entry.snapshot.fiveHour, now: now)
                UsageBar(title: UsageText.week, window: entry.snapshot.sevenDay, now: now)
            }
        }
        .padding(.vertical, UsageLayout.blockPadding)
        .opacity(entry.isStale(at: now) ? UsageLayout.dimOpacity : 1)
    }
}

private struct UsageBar: View {
    let title: String
    let window: UsageWindow?
    let now: Date

    var body: some View {
        let used = window?.used(at: now) ?? 0
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).opacity(WeekLayout.secondaryOpacity)
                Spacer(minLength: 4)
                Text(UsageText.percent(used)).fontWeight(.bold).monospacedDigit()
            }
            .font(.system(size: UsageLayout.labelSize))
            .lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(fill(for: used))
                        .frame(width: proxy.size.width * CGFloat(min(used, 100)) / 100)
                }
            }
            .frame(height: UsageLayout.barHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private var label: String {
        guard let window else { return title }
        if window.resetsAt <= now { return "\(title) · \(UsageText.alreadyReset)" }
        return "\(title) · \(UsageText.resets(window.resetsAt, now: now))"
    }

    private func fill(for used: Int) -> AnyShapeStyle {
        if used >= UsageLayout.warmLimit {
            return AnyShapeStyle(LinearGradient(colors: [NotchRim.coral, NotchRim.magenta], startPoint: .leading, endPoint: .trailing))
        }
        if used >= UsageLayout.calmLimit {
            return AnyShapeStyle(LinearGradient(colors: [NotchRim.amber, NotchRim.coral], startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(Color.white.opacity(0.75))
    }
}
