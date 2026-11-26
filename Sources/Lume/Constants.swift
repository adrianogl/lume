import SwiftUI

enum Metrics {
    static let restingEarWidth: CGFloat = 8
    static let fallbackNotchWidth: CGFloat = 120
    static let fallbackNotchMinHeight: CGFloat = 30
    static let maxNotchSize = CGSize(width: 640, height: 220)
}

enum NotchCurve {
    static let baseCornerRadius: CGFloat = 8
    static let cornerRadiusPerHeight: CGFloat = 0.17
    static let maxCornerRadius: CGFloat = 32
    static let baseFlare: CGFloat = 6
    static let flarePerHeight: CGFloat = 0.115
    static let maxFlare: CGFloat = 22

    static func cornerRadius(forHeight height: CGFloat) -> CGFloat {
        min(baseCornerRadius + height * cornerRadiusPerHeight, maxCornerRadius)
    }

    static func flare(forHeight height: CGFloat) -> CGFloat {
        min(baseFlare + height * flarePerHeight, maxFlare)
    }
}

enum NotchMotion {
    static let resize = Animation.spring(response: 0.5, dampingFraction: 0.72)
}
