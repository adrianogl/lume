import SwiftUI

struct ClosedStatusView: View {
    let meeting: MeetingStatus?
    let isMusicPlaying: Bool
    let isClaudeWaiting: Bool
    let pullRequestCount: Int
    let eyeSize: CGSize
    let eyeCenterOffset: CGFloat

    var body: some View {
        ZStack {
            if let meeting {
                meetingLayout(meeting)
            } else {
                EyesLayerView(eyeSize: eyeSize, centerDistance: eyeCenterOffset * 2, isAmber: isClaudeWaiting, isBobbing: isMusicPlaying)
                HStack {
                    Spacer(minLength: 0)
                    icons
                }
                .padding(.trailing, ClosedLayout.edgePadding)
            }
        }
    }

    private func meetingLayout(_ meeting: MeetingStatus) -> some View {
        let accent = meeting.isEnding ? NotchRim.amber : MeetingLayout.live
        return HStack(spacing: MeetingLayout.spacing) {
            EyesLayerView(
                eyeSize: MeetingLayout.eyeSize,
                centerDistance: MeetingLayout.eyeSize.width + MeetingLayout.eyeGap,
                isAmber: isClaudeWaiting,
                isBobbing: isMusicPlaying
            )
            .frame(width: MeetingLayout.eyeSize.width * 2 + MeetingLayout.eyeGap + 4, height: MeetingLayout.eyeSize.height + 4)

            Circle().fill(accent).frame(width: MeetingLayout.dotSize, height: MeetingLayout.dotSize)
            Text(MeetingText.remaining(meeting.remainingMinutes))
                .font(.system(size: MeetingLayout.fontSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(meeting.isEnding ? NotchRim.amber : .white)

            Spacer(minLength: 0)

            if let next = meeting.next {
                Text(MeetingText.next(next))
                    .font(.system(size: MeetingLayout.fontSize))
                    .opacity(WeekLayout.secondaryOpacity)
                    .lineLimit(1)
            }
            icons
        }
        .padding(.horizontal, ClosedLayout.edgePadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MeetingText.accessibility(meeting))
    }

    @ViewBuilder
    private var icons: some View {
        HStack(spacing: ClosedLayout.iconGap) {
            if isMusicPlaying {
                BarsLayerView()
                    .frame(width: BarsLayerNSView.width, height: MusicLayout.barMaxHeight)
                    .accessibilityLabel(MusicText.title)
            }
            if isClaudeWaiting {
                ClaudeMark()
                    .fill(ClaudeLayout.markColor)
                    .frame(width: ClaudeLayout.markSize, height: ClaudeLayout.markSize)
                    .accessibilityLabel(ClaudeText.pendingLabel)
            }
            if pullRequestCount > 0 {
                HStack(spacing: 2) {
                    Image(systemName: PRLayout.symbol)
                        .font(.system(size: PRLayout.symbolSize, weight: .semibold))
                    Text("\(pullRequestCount)")
                        .font(.system(size: PRLayout.countSize, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(NotchRim.amber)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(PRText.attentionLabel)
            }
        }
    }
}
