import AppKit

@MainActor
final class NotchHoverMonitor {
    private let model: NotchModel
    private let panel: NSPanel
    private let screenFrame: NSRect
    private var monitors: [Any] = []

    init(model: NotchModel, panel: NSPanel, screenFrame: NSRect) {
        self.model = model
        self.panel = panel
        self.screenFrame = screenFrame
    }

    func start() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            handler(event)
            return event
        }) {
            monitors.append(local)
        }
        check()
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func check() {
        let inside = notchRect.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !inside
        model.hoverChanged(inside)
    }

    private var notchRect: NSRect {
        let flare = NotchCurve.flare(forHeight: model.size.height)
        let slop = model.isOpen ? 0 : NotchHover.restingSlop
        let width = model.size.width + flare * 2 + slop * 2
        let height = model.size.height + slop
        return NSRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }
}
