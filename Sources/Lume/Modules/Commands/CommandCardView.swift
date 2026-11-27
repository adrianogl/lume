import SwiftUI

struct CommandCardView: View {
    @ObservedObject var monitor: CommandMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: CommandCard.refresh)) { timeline in
            VStack(alignment: .leading, spacing: CommandCard.rowSpacing) {
                HStack(spacing: 6) {
                    Image(systemName: CommandLayout.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(NotchRim.amber)
                    Text(CommandText.title).font(.system(size: WeekLayout.titleSize, weight: .semibold))
                    Spacer(minLength: 0)
                    if !monitor.running.isEmpty {
                        CommandSpinner()
                    }
                    Text(CommandText.runningCount(monitor.running.count))
                        .font(.system(size: WeekLayout.metaSize))
                        .foregroundStyle(.white.opacity(WeekLayout.secondaryOpacity))
                }
                .padding(.top, WeekLayout.headerTop)
                .padding(.bottom, 2)

                if monitor.runs.isEmpty, monitor.running.isEmpty {
                    Text(CommandText.empty)
                        .font(.system(size: WeekLayout.rowSize))
                        .opacity(WeekLayout.secondaryOpacity)
                        .padding(.top, 12)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: CommandCard.rowSpacing) {
                            ForEach(monitor.running) { item in
                                CommandRow(
                                    tag: CommandText.runningTag,
                                    color: NotchRim.amber,
                                    command: item.command,
                                    detail: [item.project, CommandText.duration(timeline.date.timeIntervalSince(item.startedAt))].filter { !$0.isEmpty }.joined(separator: " · "),
                                    ago: "",
                                    isDim: false,
                                    bundleID: item.bundleID,
                                    terminalSession: item.terminalSession
                                )
                            }
                            ForEach(monitor.runs) { run in
                                CommandRow(
                                    tag: run.outcome.tag,
                                    color: run.outcome.color,
                                    command: run.command,
                                    detail: run.subtitle,
                                    ago: CommandText.ago(from: run.finishedAt, to: timeline.date),
                                    isDim: !run.outcome.isFailure && timeline.date.timeIntervalSince(run.finishedAt) > CommandCard.dimAfter,
                                    bundleID: run.bundleID,
                                    terminalSession: run.terminalSession
                                )
                            }
                        }
                    }
                    .frame(height: CommandCard.listHeight)
                }
            }
            .padding(.horizontal, WeekLayout.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct CommandRow: View {
    let tag: String
    let color: Color
    let command: String
    let detail: String
    let ago: String
    let isDim: Bool
    let bundleID: String?
    let terminalSession: String?

    var body: some View {
        HStack(spacing: 7) {
            Text(tag)
                .font(.system(size: ClaudeLayout.tagSize - 1, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.18)))
                .fixedSize()
            Text(command)
                .font(.system(size: CommandCard.commandSize, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Text(detail)
                .font(.system(size: CommandCard.textSize))
                .opacity(WeekLayout.secondaryOpacity)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !ago.isEmpty {
                Text(ago)
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .opacity(0.4)
                    .fixedSize()
            }
            if let bundleID {
                Button {
                    ClaudeCodeMonitor.open(bundleID: bundleID, terminalSession: terminalSession)
                } label: {
                    Text(CommandText.open)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(isDim ? Color.white : Color.black)
                        .padding(.horizontal, 8)
                        .frame(height: 17)
                        .background(Capsule().fill(isDim ? Color.white.opacity(0.14) : Color.white))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: CommandCard.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(isDim ? 0.035 : 0.07)))
        .opacity(isDim ? 0.6 : 1)
    }
}

struct CommandSpinner: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let turns = timeline.date.timeIntervalSinceReferenceDate / CommandLayout.spinnerPeriod
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: CommandLayout.spinnerLine)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(NotchRim.amber, style: StrokeStyle(lineWidth: CommandLayout.spinnerLine, lineCap: .round))
                    .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
            }
            .frame(width: CommandLayout.spinnerSize, height: CommandLayout.spinnerSize)
        }
    }
}

struct RunningCommandBadge: View {
    let status: RunningCommandStatus

    var body: some View {
        HStack(spacing: 4) {
            CommandSpinner()
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(CommandText.elapsed(timeline.date.timeIntervalSince(status.startedAt)))
                    .font(.system(size: CommandLayout.runningFontSize, weight: .semibold))
                    .monospacedDigit()
            }
        }
        .frame(width: CommandLayout.runningWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CommandText.runningLabel)
    }
}
