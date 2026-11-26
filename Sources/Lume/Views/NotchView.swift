import SwiftUI

struct NotchView: View {
    @ObservedObject var model: NotchModel
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

            if model.isResting {
                HStack(spacing: eyeCenterOffset * 2 - eyeSize.width) {
                    OwlEye(size: eyeSize, isBlinking: isBlinking)
                    OwlEye(size: eyeSize, isBlinking: isBlinking)
                }
                .frame(height: model.restingSize.height)
                .transition(.opacity)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .top)
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
