import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var model: NotchModel?
    private var screenObserver: Any?
    private var hover: NotchHoverMonitor?
    private var swipe: PageSwipeMonitor?
    private let config = ConfigStore()
    private let week = WeekEventStore()
    private var configSubscription: AnyCancellable?
    private lazy var settings = SettingsWindowController(config: config, week: week)

    func applicationDidFinishLaunching(_ notification: Notification) {
        config.start()
        showNotch()
        configSubscription = config.$config.sink { [weak self] newConfig in
            self?.apply(newConfig)
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showNotch() }
        }
    }

    private func apply(_ newConfig: LumeConfig) {
        week.apply(newConfig.modules.week)
        model?.setPages(NotchPage.enabled(in: newConfig))
    }

    private func showNotch() {
        hover?.stop()
        hover = nil
        swipe?.stop()
        swipe = nil
        panel?.orderOut(nil)
        panel = nil
        guard let geometry = NotchGeometry.current() else { return }

        let model = NotchModel(restingSize: geometry.restingSize)
        model.setPages(NotchPage.enabled(in: config.config))
        model.openSettings = { [weak self] in self?.settings.show(on: geometry.screen) }
        let frame = geometry.windowFrame
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true
        let root = NotchView(
            model: model,
            config: config,
            week: week,
            canvasSize: frame.size,
            eyeCenterOffset: eyeCenterOffset(for: geometry)
        )
        let host = FirstClickHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.model = model

        let hover = NotchHoverMonitor(model: model, panel: panel, screenFrame: geometry.screen.frame)
        hover.start()
        self.hover = hover

        let swipe = PageSwipeMonitor(model: model)
        swipe.start()
        self.swipe = swipe
    }

    private func eyeCenterOffset(for geometry: NotchGeometry) -> CGFloat {
        if geometry.hasPhysicalNotch {
            return geometry.notchSize.width / 2 + geometry.earWidth / 2
        }
        return geometry.notchSize.height * OwlEyes.centeredSpacingRatio / 2
    }
}
