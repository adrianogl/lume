import SwiftUI

struct MeetingStripView: View {
    let meeting: MeetingStatus
    let isBlinking: Bool

    private var accent: Color { meeting.isEnding ? NotchRim.amber : MeetingLayout.live }

    var body: some View {
        HStack(spacing: MeetingLayout.spacing) {
            HStack(spacing: MeetingLayout.eyeGap) {
                OwlEye(size: MeetingLayout.eyeSize, isBlinking: isBlinking)
                OwlEye(size: MeetingLayout.eyeSize, isBlinking: isBlinking)
            }
            Circle()
                .fill(accent)
                .frame(width: MeetingLayout.dotSize, height: MeetingLayout.dotSize)
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
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, MeetingLayout.horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MeetingText.accessibility(meeting))
    }
}
