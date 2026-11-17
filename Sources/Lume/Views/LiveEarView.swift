import SwiftUI

struct LiveEarView: View {
    let live: LiveEvent
    let title: String
    var joinURL: URL? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(context.date.timeIntervalSince(live.start), 0)
            let total = max(live.end.timeIntervalSince(live.start), 1)

            HStack(spacing: 6) {
                PulsingDot()
                Text(Self.clock(elapsed))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.live)
                    .fixedSize()
                Text("/ \(AgendaBuilder.duration(total))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize()
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                if let joinURL {
                    JoinButton(url: joinURL)
                }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ProgressLine(fraction: elapsed / total)
                    .padding(.bottom, 3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reunião em andamento: \(title), \(Self.clock(elapsed)) de \(AgendaBuilder.duration(total))")
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, rest) }
        return String(format: "%02d:%02d", minutes, rest)
    }
}

private struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Palette.live)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 2)
    }
}

private struct PulsingDot: View {
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(Palette.live)
            .frame(width: 7, height: 7)
            .background(
                Circle()
                    .fill(Palette.live.opacity(isPulsing ? 0 : 0.55))
                    .scaleEffect(isPulsing ? 2.6 : 1)
            )
            .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isPulsing)
            .onAppear { isPulsing = !reduceMotion }
    }
}
