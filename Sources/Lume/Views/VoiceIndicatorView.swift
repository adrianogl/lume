import SwiftUI

struct VoiceIndicatorView: View {
    let state: VoiceState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch state {
        case .idle:
            BreathingBars(levels: VoiceConfig.idleLevels, isAnimated: !reduceMotion)
                .accessibilityLabel("Aguardando")
        case .listening:
            EqualizerBars(color: Palette.redLight)
                .accessibilityLabel("Ouvindo")
        case .processing:
            ProcessingDots()
                .accessibilityLabel("Processando")
        case .unavailable:
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
                .accessibilityLabel("Microfone indisponível")
        }
    }
}

private struct BreathingBars: View {
    let levels: [Double]
    let isAnimated: Bool
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.32))
                    .frame(width: 2.2, height: 12 * levels[index])
                    .scaleEffect(x: 1, y: isExpanded ? 1 : VoiceConfig.idleMinScale, anchor: .center)
                    .animation(
                        isAnimated
                            ? .easeInOut(duration: VoiceConfig.idleBreathPeriod / 2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * VoiceConfig.idleBreathStagger)
                            : nil,
                        value: isExpanded
                    )
            }
        }
        .frame(height: 12)
        .drawingGroup()
        .onAppear { isExpanded = isAnimated }
    }
}

private struct ProcessingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = (sin(time * 5 - Double(index) * 0.8) + 1) / 2
                    Circle()
                        .fill(Color.white.opacity(0.3 + 0.7 * phase))
                        .frame(width: 4, height: 4)
                }
            }
        }
    }
}
