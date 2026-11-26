import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var model: NotchModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.current() else { return }

        let model = NotchModel(restingSize: geometry.restingSize)
        let frame = geometry.windowFrame
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true
        let host = NSHostingView(rootView: NotchView(model: model, canvasSize: frame.size))
        host.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.model = model
    }
}
