import AVFoundation

@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()

    private lazy var voice: AVSpeechSynthesisVoice? = {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == VoiceConfig.localeID }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: VoiceConfig.localeID)
    }()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = BrainConfig.speechRate
        synthesizer.speak(utterance)
    }
}
