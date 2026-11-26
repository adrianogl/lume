import SwiftUI

struct OwlBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = CGRect(x: 14, y: 30, width: 112, height: 96)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + (x - box.minX) / box.width * rect.width,
                y: rect.minY + (y - box.minY) / box.height * rect.height
            )
        }
        var path = Path()
        path.move(to: p(70, 40))
        path.addCurve(to: p(36, 30), control1: p(54, 40), control2: p(44, 36))
        path.addCurve(to: p(28, 52), control1: p(37, 40), control2: p(34, 46))
        path.addCurve(to: p(14, 84), control1: p(20, 60), control2: p(14, 72))
        path.addCurve(to: p(70, 126), control1: p(14, 110), control2: p(40, 126))
        path.addCurve(to: p(126, 84), control1: p(100, 126), control2: p(126, 110))
        path.addCurve(to: p(112, 52), control1: p(126, 72), control2: p(120, 60))
        path.addCurve(to: p(104, 30), control1: p(106, 46), control2: p(103, 40))
        path.addCurve(to: p(70, 40), control1: p(96, 36), control2: p(86, 40))
        path.closeSubpath()
        return path
    }
}

struct OwlMascot: View {
    let width: CGFloat
    let isBlinking: Bool

    private var height: CGFloat { width * OwlShape.heightRatio }

    var body: some View {
        ZStack {
            OwlBodyShape()
                .fill(LinearGradient(colors: OwlShape.rimColors, startPoint: .leading, endPoint: .trailing))
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: OwlShape.rimFadeStart),
                            .init(color: .black, location: OwlShape.rimFadeEnd)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            OwlBodyShape()
                .fill(LinearGradient(colors: OwlShape.bodyColors, startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: OwlShape.innerScale.width, y: OwlShape.innerScale.height, anchor: .top)

            ForEach(OwlShape.eyeCenters.indices, id: \.self) { index in
                let center = OwlShape.eyeCenters[index]
                OwlEye(
                    size: CGSize(width: width * OwlShape.eyeSize.width, height: height * OwlShape.eyeSize.height),
                    isBlinking: isBlinking
                )
                .position(x: width * center.x, y: height * center.y)
            }
        }
        .frame(width: width, height: height)
    }
}
