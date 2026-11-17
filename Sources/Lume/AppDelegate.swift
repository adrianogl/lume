import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private var model: NotchModel?
    private var voice: VoiceController?
    private var music: NowPlayingMonitor?
    private var agenda: AgendaProvider?
    private let usage = UsageStore()
    private var prs: PullRequestStore?
    private var training: TrainingProvider?
    private var monitors: [Any] = []
    private var claudeHooks: ClaudeHookBridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.current() else { return }

        let model = NotchModel(
            categories: [AgendaConfig.placeholder, PRConfig.category, TrainingConfig.category, UsageConfig.category],
            notchSize: geometry.notchSize,
            hasPhysicalNotch: geometry.hasPhysicalNotch
        )
        let prs = PullRequestStore(model: model)
        self.prs = prs
        let frame = geometry.windowFrame
        let panel = NotchPanel(contentRect: frame)
        let host = NSHostingView(rootView: NotchView(model: model, usage: usage, prs: prs))
        host.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = host
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        self.panel = panel
        self.model = model
        installMonitors(model: model)

        let voice = VoiceController(model: model)
        let brain = LumeBrain(model: model, prs: prs, usage: usage)
        voice.answer = { await brain.answer($0) }
        voice.start()
        self.voice = voice

        let music = NowPlayingMonitor(model: model)
        music.start()
        model.onMusicCommand = { [weak music] in music?.send($0) }
        self.music = music

        let agenda = AgendaProvider(model: model)
        agenda.start()
        self.agenda = agenda

        usage.start()
        prs.start()

        let claudeHooks = ClaudeHookBridge(model: model)
        claudeHooks.start()
        self.claudeHooks = claudeHooks

        let training = TrainingProvider(model: model)
        training.start()
        self.training = training

        if ProcessInfo.processInfo.environment[LaunchOptions.demoAlertKey] != nil {
            model.present(NotchAlert(kind: .failure, title: "CI falhou", subtitle: "front-mef #2018 · Corrige total sem imposto", actionTitle: "Abrir PR", actionURL: URL(string: "https://github.com")))
            model.present(NotchAlert(kind: .meeting, title: "Daily do time em 5 min", subtitle: "Reuniões do Microsoft Teams · 10:30–10:45", actionTitle: "Entrar", actionURL: URL(string: "https://teams.microsoft.com")))
        }

        if let start = ProcessInfo.processInfo.environment[LaunchOptions.startOpenKey] {
            if model.categories.contains(where: { $0.id == start }) {
                model.show(categoryID: start)
            } else {
                model.open(pin: true)
            }
        }
    }

    private func installMonitors(model: NotchModel) {
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = event.charactersIgnoringModifiers ?? ""
            guard model.isOpen else { return event }
            if event.keyCode == 53 {
                model.close()
                return nil
            }
            if let number = Int(key), number >= 1 {
                model.select(index: number - 1)
                return nil
            }
            return event
        }

        let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            Task { @MainActor in
                if model.isPinned { model.close() }
            }
        }

        monitors = [keys, clicks].compactMap { $0 }
    }
}
