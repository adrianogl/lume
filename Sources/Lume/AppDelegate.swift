import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var model: NotchModel?
    private var screenObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showNotch()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showNotch() }
        }
    }

    private func showNotch() {
        panel?.orderOut(nil)
        panel = nil
        guard let geometry = NotchGeometry.current() else { return }

        let model = NotchModel(restingSize: geometry.restingSize)
        let frame = geometry.windowFrame
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true
        let host = NSHostingView(rootView: NotchView(model: model, canvasSize: frame.size, eyeCenterOffset: eyeCenterOffset(for: geometry)))
        host.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.model = model
    }

    private func eyeCenterOffset(for geometry: NotchGeometry) -> CGFloat {
        if geometry.hasPhysicalNotch {
            return geometry.notchSize.width / 2 + geometry.earWidth / 2
        }
        return geometry.notchSize.height * OwlEyes.centeredSpacingRatio / 2
    }
}
