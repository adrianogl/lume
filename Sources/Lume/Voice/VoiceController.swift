import AppKit
import AVFoundation
import Speech

@MainActor
final class VoiceController {
    private enum Mode {
        case wake, command
    }

    private let model: NotchModel
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: VoiceConfig.localeID))
    private let engine = AVAudioEngine()
    private let feed = AudioFeed()
    private var task: SFSpeechRecognitionTask?
    private var generation = 0
    private var mode: Mode = .wake
    private var command = ""
    private var silenceTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private let speaker = Speaker()
    var answer: ((String) async -> BrainReply)?

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        Task {
            guard await SpeechSupport.requestPermissions(),
                  let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
                model.voice = .unavailable
                return
            }
            do {
                feed.install(on: engine.inputNode)
                engine.prepare()
                try engine.start()
                listenForWakeWord()
            } catch {
                model.voice = .unavailable
            }
        }
    }

    private func listenForWakeWord() {
        mode = .wake
        command = ""
        beginRecognition()
        scheduleRestart(after: VoiceConfig.wakeRestartInterval)
    }

    private func beginRecognition() {
        guard let recognizer else { return }
        task?.cancel()
        generation += 1
        let current = generation

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        feed.set(request)

        task = SpeechSupport.recognitionTask(recognizer: recognizer, request: request) { [weak self] text, isFinal, failed in
            Task { @MainActor in
                self?.handle(text: text, isFinal: isFinal, failed: failed, generation: current)
            }
        }
    }

    private func handle(text: String, isFinal: Bool, failed: Bool, generation: Int) {
        guard generation == self.generation else { return }

        if failed {
            scheduleRestart(after: VoiceConfig.failureRestartDelay)
            return
        }

        switch mode {
        case .wake:
            if let initial = WakeWordMatcher.commandAfterWakeWord(in: text) {
                startCommand(initial: initial)
                if isFinal { finishCommand() }
            } else if isFinal {
                scheduleRestart(after: 0.2)
            }
        case .command:
            updateCommand(WakeWordMatcher.commandAfterWakeWord(in: text) ?? text)
            if isFinal { finishCommand() }
        }
    }

    private func startCommand(initial: String) {
        mode = .command
        restartTask?.cancel()
        NSSound(named: VoiceConfig.wakeSoundName)?.play()
        command = initial
        model.voice = .listening
        model.exchange = VoiceExchange(heard: initial)
        model.open(pin: true)
        scheduleSilence(after: initial.isEmpty ? VoiceConfig.commandStartTimeout : VoiceConfig.commandSilence)
    }

    private func updateCommand(_ text: String) {
        guard text != command else { return }
        command = text
        model.exchange = VoiceExchange(heard: text)
        scheduleSilence(after: VoiceConfig.commandSilence)
    }

    private func scheduleSilence(after seconds: Double) {
        silenceTask?.cancel()
        silenceTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            finishCommand()
        }
    }

    private func finishCommand() {
        guard mode == .command else { return }
        silenceTask?.cancel()
        let heard = command
        listenForWakeWord()

        guard !heard.isEmpty else {
            model.voice = .idle
            model.close()
            return
        }

        model.voice = .processing
        Task {
            let reply = await answer?(heard) ?? BrainReply(text: VoiceConfig.placeholderReply)
            model.voice = .idle
            model.exchange = VoiceExchange(heard: heard, reply: reply.text)
            if let categoryID = reply.categoryID {
                model.activeID = categoryID
            }
            speaker.speak(reply.text)
        }
    }

    private func scheduleRestart(after seconds: Double) {
        restartTask?.cancel()
        restartTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if mode == .command {
                finishCommand()
            } else {
                listenForWakeWord()
            }
        }
    }
}
