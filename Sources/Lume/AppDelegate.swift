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
    private let music = MusicController()
    private var musicSubscription: AnyCancellable?
    private lazy var alerts = EventAlertScheduler(store: week) { [weak self] alert in
        self?.model?.present(.event(alert))
    }
    private lazy var claude = ClaudeCodeMonitor { [weak self] alert in
        self?.model?.present(.claude(alert))
    }
    private var claudeSubscription: AnyCancellable?
    private lazy var pullRequests = PullRequestMonitor { [weak self] alert in
        self?.model?.markNewPullRequestAlert()
        self?.model?.present(.pullRequest(alert))
    }
    private var pullRequestSubscription: AnyCancellable?
    private lazy var usage = ClaudeUsageMonitor { [weak self] alert in
        self?.model?.present(.usage(alert))
    }
    private var usageSubscription: AnyCancellable?
    private lazy var meetings = MeetingTracker(store: week) { [weak self] status in
        guard ProcessInfo.processInfo.environment[LaunchOptions.demoMeeting] == nil else { return }
        self?.model?.setMeeting(status)
    }
    private var configSubscription: AnyCancellable?
    private var eventsSubscription: AnyCancellable?
    private lazy var settings = SettingsWindowController(config: config, week: week, pullRequests: pullRequests)

    func applicationDidFinishLaunching(_ notification: Notification) {
        config.start()
        showNotch()
        configSubscription = config.$config.sink { [weak self] newConfig in
            self?.apply(newConfig)
        }
        claudeSubscription = claude.$pendingCount.sink { [weak self] count in
            self?.model?.setClaudeWaiting(count > 0)
        }
        pullRequestSubscription = pullRequests.$attentionCount.sink { [weak self] count in
            self?.model?.setPullRequestCount(count)
        }
        usageSubscription = usage.$closedPercent.sink { [weak self] percent in
            self?.model?.setUsagePercent(percent)
        }
        musicSubscription = music.$isActive.sink { [weak self] active in
            self?.model?.setMusicActive(active)
        }
        eventsSubscription = week.$events.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.meetings.update() }
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
        alerts.apply(newConfig.modules.week)
        meetings.apply(newConfig.modules.week)
        music.apply(newConfig.modules.music)
        claude.apply(newConfig.modules.claudeCode)
        pullRequests.apply(newConfig.modules.pullRequests)
        usage.apply(newConfig.modules.claudeUsage, accountNames: newConfig.modules.claudeCode.accountNames)
        model?.alertFeedback = newConfig.modules.week.alerts
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

        let model = NotchModel(
            restingSize: geometry.restingSize,
            contentTopInset: geometry.hasPhysicalNotch ? geometry.notchSize.height : 0
        )
        model.setPages(NotchPage.enabled(in: config.config))
        model.alertFeedback = config.config.modules.week.alerts
        model.openSettings = { [weak self] in self?.settings.show(on: geometry.screen) }
        let frame = geometry.windowFrame
        let panel = NotchPanel(contentRect: frame)
        panel.ignoresMouseEvents = true
        let root = NotchView(
            model: model,
            config: config,
            week: week,
            music: music,
            claude: claude,
            pullRequests: pullRequests,
            usage: usage,
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
        meetings.update()
        model.setMusicActive(music.isActive)
        model.setClaudeWaiting(claude.pendingCount > 0)
        model.setPullRequestCount(pullRequests.attentionCount)
        model.setUsagePercent(usage.closedPercent)

        let hover = NotchHoverMonitor(model: model, panel: panel, screenFrame: geometry.screen.frame)
        hover.start()
        self.hover = hover

        let swipe = PageSwipeMonitor(model: model)
        swipe.start()
        self.swipe = swipe

        if ProcessInfo.processInfo.environment[LaunchOptions.demoAlert] != nil {
            model.present(.event(DemoAlert.make()))
        }
        if let demo = ProcessInfo.processInfo.environment[LaunchOptions.demoMeeting] {
            model.setMeeting(DemoMeeting.make(ending: demo == "ending"))
        }
    }

    private func eyeCenterOffset(for geometry: NotchGeometry) -> CGFloat {
        if geometry.hasPhysicalNotch {
            return geometry.notchSize.width / 2 + geometry.earWidth / 2
        }
        return geometry.notchSize.height * OwlEyes.centeredSpacingRatio / 2
    }
}
