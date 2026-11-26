import SwiftUI

@MainActor
final class NotchModel: ObservableObject {
    @Published private(set) var size: CGSize
    let restingSize: CGSize

    init(restingSize: CGSize) {
        self.restingSize = restingSize
        self.size = restingSize
    }

    func resize(toFit content: CGSize) {
        let target = CGSize(
            width: min(max(content.width, restingSize.width), Metrics.maxNotchSize.width),
            height: min(max(content.height, restingSize.height), Metrics.maxNotchSize.height)
        )
        guard target != size else { return }
        withAnimation(NotchMotion.resize) { size = target }
    }

    func rest() {
        resize(toFit: restingSize)
    }
}
