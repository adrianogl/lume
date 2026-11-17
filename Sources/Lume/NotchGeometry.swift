import AppKit

struct NotchGeometry {
    let screen: NSScreen
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

    static func current() -> NotchGeometry? {
        let notched = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notched ?? NSScreen.main else { return nil }

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            let width = screen.frame.width - left.width - right.width
            return NotchGeometry(screen: screen, notchSize: CGSize(width: width, height: screen.safeAreaInsets.top), hasPhysicalNotch: true)
        }

        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, Metrics.fallbackNotchMinHeight)
        return NotchGeometry(screen: screen, notchSize: CGSize(width: Metrics.fallbackNotchWidth, height: menuBarHeight), hasPhysicalNotch: false)
    }

    var windowFrame: NSRect {
        NSRect(
            x: screen.frame.midX - Metrics.windowSize.width / 2,
            y: screen.frame.maxY - Metrics.windowSize.height,
            width: Metrics.windowSize.width,
            height: Metrics.windowSize.height
        )
    }
}
