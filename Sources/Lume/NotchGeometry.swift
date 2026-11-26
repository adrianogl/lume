import AppKit

struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize

    static func current() -> NotchGeometry? {
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notched ?? NSScreen.screens.first else { return nil }

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            let width = screen.frame.width - left.width - right.width
            return NotchGeometry(screen: screen, notchSize: CGSize(width: width, height: screen.safeAreaInsets.top))
        }

        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, Metrics.fallbackNotchMinHeight)
        return NotchGeometry(screen: screen, notchSize: CGSize(width: Metrics.fallbackNotchWidth, height: menuBarHeight))
    }

    var restingSize: CGSize {
        CGSize(width: notchSize.width + Metrics.restingEarWidth * 2, height: notchSize.height)
    }

    var canvasSize: CGSize {
        let maxFlare = NotchCurve.flare(forHeight: Metrics.maxNotchSize.height)
        return CGSize(
            width: max(Metrics.maxNotchSize.width, restingSize.width) + maxFlare * 2,
            height: max(Metrics.maxNotchSize.height, restingSize.height)
        )
    }

    var windowFrame: NSRect {
        let size = canvasSize
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
