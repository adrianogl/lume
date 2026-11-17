import SwiftUI

struct LogoView: View {
    let size: CGFloat
    var circleColor: Color = Palette.red
    var barColor: Color = .white

    private let barLengths: [CGFloat] = [10, 30, 48, 26, 10]

    var body: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: size * 0.84, height: size * 0.84)
            HStack(spacing: size * 0.03) {
                ForEach(barLengths.indices, id: \.self) { index in
                    Capsule()
                        .fill(barColor)
                        .frame(width: size * 0.075, height: size * (barLengths[index] + 7.5) / 100)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
