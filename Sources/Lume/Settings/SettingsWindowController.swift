import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let config: ConfigStore
    private let week: WeekEventStore
    private let pullRequests: PullRequestMonitor
    private var window: NSWindow?

    init(config: ConfigStore, week: WeekEventStore, pullRequests: PullRequestMonitor) {
        self.config = config
        self.week = week
        self.pullRequests = pullRequests
    }

    func show(on screen: NSScreen?) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: SettingsLayout.size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = SettingsText.windowTitle
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(config: config, week: week, pullRequests: pullRequests))
            self.window = window
        }
        if let window, let visible = screen?.visibleFrame, !window.isVisible {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
