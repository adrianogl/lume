import SwiftUI

struct OwlEye: View {
    let size: CGSize
    let isBlinking: Bool

    var body: some View {
        Ellipse()
            .fill(OwlEyes.color)
            .frame(width: size.width, height: size.height)
            .shadow(color: OwlEyes.color.opacity(OwlEyes.glowOpacity), radius: OwlEyes.glowRadius)
            .shadow(color: OwlEyes.color.opacity(OwlEyes.haloOpacity), radius: OwlEyes.haloRadius)
            .scaleEffect(x: 1, y: isBlinking ? 0.1 : 1)
    }
}
