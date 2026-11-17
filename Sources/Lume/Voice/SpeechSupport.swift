import AVFoundation
import Speech

final class AudioFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock()
        defer { lock.unlock() }
        self.request = request
    }

    func install(on node: AVAudioInputNode) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.append(buffer)
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}

enum SpeechSupport {
    static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func recognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String, Bool, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString ?? "", result?.isFinal ?? false, error != nil)
        }
    }
}

enum WakeWordMatcher {
    static func commandAfterWakeWord(in text: String) -> String? {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: VoiceConfig.localeID))
        let pattern = "\\b(" + VoiceConfig.wakeWords.joined(separator: "|") + ")\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let matches = regex.matches(in: folded, range: NSRange(folded.startIndex..., in: folded))
        guard let last = matches.last, let range = Range(last.range, in: folded) else { return nil }

        let offset = folded.distance(from: folded.startIndex, to: range.upperBound)
        let source = folded.count == text.count ? text : folded
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return String(source.dropFirst(offset)).trimmingCharacters(in: separators)
    }
}
