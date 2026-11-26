import SwiftUI

enum Metrics {
    static let restingEarWidth: CGFloat = 8
    static let eyeEarPadding: CGFloat = 7
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

enum NotchRim {
    static let bottomThickness: CGFloat = 2.5
    static let sideThickness: CGFloat = 1.2
    static let amber = Color(red: 1, green: 179 / 255, blue: 107 / 255)
    static let coral = Color(red: 1, green: 106 / 255, blue: 77 / 255)
    static let magenta = Color(red: 214 / 255, green: 51 / 255, blue: 108 / 255)
    static let colors = [amber, coral, magenta, coral, amber]
    static let flowPeriod: Double = 6
    static let fadeStart: CGFloat = 0.2
    static let fadeEnd: CGFloat = 0.85
}

enum OwlEyes {
    static let widthRatio: CGFloat = 0.3
    static let heightRatio: CGFloat = 0.46
    static let centeredSpacingRatio: CGFloat = 0.8
    static let blinkInterval: Double = 4.2
    static let blinkDuration: Double = 0.09
    static let color = Color.white
    static let glowOpacity: Double = 0.7
    static let glowRadius: CGFloat = 1.5
    static let haloOpacity: Double = 0.22
    static let haloRadius: CGFloat = 5

    static func size(forNotchHeight height: CGFloat) -> CGSize {
        CGSize(width: (height * widthRatio).rounded(), height: (height * heightRatio).rounded())
    }
}
