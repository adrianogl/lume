import SwiftUI

struct EqualizerBars: View {
    let color: Color
    var isAnimating = true
    var barCount = 4
    var maxHeight: CGFloat = 12
    var restLevels: [Double] = [0.35, 0.75, 0.5, 0.9, 0.4]
    var barWidth: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: 3 + (maxHeight - 3) * level(index: index, time: time))
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func level(index: Int, time: TimeInterval) -> Double {
        guard isAnimating else { return restLevels[index % restLevels.count] }
        return (sin(time * (5 + Double(index)) + Double(index) * 1.3) + 1) / 2
    }
}
