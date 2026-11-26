import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchModel
    let config: ConfigStore
    let week: WeekEventStore
    let canvasSize: CGSize
    let eyeCenterOffset: CGFloat
    @State private var isBlinking = false

    private var eyeSize: CGSize { OwlEyes.size(forNotchHeight: model.restingSize.height) }


    var body: some View {
        let flare = NotchCurve.flare(forHeight: model.size.height)
        let radius = NotchCurve.cornerRadius(forHeight: model.size.height)
        ZStack(alignment: .top) {
            RimGradientView(topRadius: flare, bottomRadius: radius)
                .frame(width: model.size.width + flare * 2, height: model.size.height)

            NotchShape(topRadius: flare, bottomRadius: max(radius - NotchRim.bottomThickness, 0))
                .fill(.black)
                .frame(
                    width: model.size.width + flare * 2 - NotchRim.sideThickness * 2,
                    height: model.size.height - NotchRim.bottomThickness
                )

            ZStack(alignment: .topLeading) {
                if model.isOpen {
                    OpenNotchContent(model: model, config: config, week: week)
                        .transition(.opacity.animation(OpenLayout.contentFade))

                    if model.currentPage == .clock {
                        OwlMascot(width: OpenLayout.mascotWidth, isBlinking: isBlinking)
                            .offset(x: OpenLayout.mascotOrigin.x, y: OpenLayout.mascotOrigin.y)
                            .transition(.scale(scale: OpenLayout.mascotAppearScale, anchor: .topLeading).combined(with: .opacity))
                    }
                } else {
                    HStack(spacing: eyeCenterOffset * 2 - eyeSize.width) {
                        OwlEye(size: eyeSize, isBlinking: isBlinking)
                        OwlEye(size: eyeSize, isBlinking: isBlinking)
                    }
                    .position(x: model.size.width / 2, y: model.restingSize.height / 2)
                    .transition(.opacity)
                }
            }
            .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .top)
        .foregroundStyle(.white)
        .task { await blinkForever() }
    }

    private func blinkForever() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(OwlEyes.blinkInterval))
            withAnimation(.easeInOut(duration: OwlEyes.blinkDuration)) { isBlinking = true }
            try? await Task.sleep(for: .seconds(OwlEyes.blinkDuration * 1.5))
            withAnimation(.easeInOut(duration: OwlEyes.blinkDuration)) { isBlinking = false }
        }
    }
}
