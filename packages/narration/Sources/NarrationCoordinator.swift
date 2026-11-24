import AVFoundation
import Foundation
import Observation
import LearningEngine

@MainActor
@Observable
public final class NarrationCoordinator: NSObject, AVSpeechSynthesizerDelegate {
    public enum PlaybackState { case idle, playing, paused }

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var timingTimer: Timer?
    private var timeline = WordTimeline(sentence: "", timedWords: [])
    private var completion: (() -> Void)?
    /// Identifies the utterance or player whose callbacks may still change state.
    private var activeSource: ObjectIdentifier?
    private var isolatedWordIndex: Int?
    private var sliceEnd: TimeInterval?
    private let configuration: NarrationSettings
    private let manifest: AudioManifest
    private let settings: SoundSettings
    private let fallbackVoice: AVSpeechSynthesisVoice?

    public private(set) var text = ""
    public private(set) var tokens: [WordToken] = []
    public private(set) var currentWordIndex: Int?
    public private(set) var completedWordCount = 0
    public private(set) var state: PlaybackState = .idle
    public var isSlow = false

    public init(configuration: NarrationSettings = NarrationSettings(), bundle: Bundle = .main, settings: SoundSettings = SoundSettings()) {
        self.configuration = configuration
        self.settings = settings
        manifest = AudioManifest(bundle: bundle, resourceName: configuration.bundledManifestName)
        fallbackVoice = Self.bestVoice(for: configuration.language)
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    /// Whether `sentence` plays from a bundled recording instead of the on-device voice.
    public func hasRecording(for sentence: String) -> Bool { manifest.clipURL(for: sentence) != nil }

    public func play(_ sentence: String, completion: (() -> Void)? = nil) {
        stop()
        guard !sentence.isEmpty else { return }
        text = sentence
        tokens = sentence.wordTokens
        self.completion = completion
        guard settings.voiceEnabled else {
            finish()
            return
        }
        state = .playing
        if startRecording(for: sentence, from: nil) { return }

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.postUtteranceDelay = 0.05
        speak(utterance)
    }

    /// Speaks one word of `sentence`, cut from the sentence's own recording so the voice stays the same.
    public func speakWord(_ word: String, at index: Int, in sentence: String) {
        stop()
        guard settings.voiceEnabled else { return }
        text = sentence
        tokens = sentence.wordTokens
        currentWordIndex = index
        completedWordCount = index
        isolatedWordIndex = index
        state = .playing
        if startRecording(for: sentence, from: index) { return }
        speak(AVSpeechUtterance(string: word))
    }

    public func replay() {
        guard !text.isEmpty else { return }
        play(text, completion: completion)
    }

    public func togglePause() {
        switch state {
        case .playing:
            if let player {
                player.pause()
                state = .paused
            } else if synthesizer.pauseSpeaking(at: .word) {
                state = .paused
            }
        case .paused:
            if let player {
                player.play()
                state = .playing
            } else if synthesizer.continueSpeaking() {
                state = .playing
            }
        case .idle:
            replay()
        }
    }

    public func setSlow(_ slow: Bool) {
        isSlow = slow
        if state != .idle { replay() }
    }

    public func stop() {
        activeSource = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
        player?.stop()
        player = nil
        timingTimer?.invalidate()
        timingTimer = nil
        isolatedWordIndex = nil
        sliceEnd = nil
        completion = nil
        currentWordIndex = nil
        completedWordCount = 0
        state = .idle
    }

    // MARK: Recorded narration

    private func startRecording(for sentence: String, from wordIndex: Int?) -> Bool {
        guard let entry = manifest.entry(for: sentence),
              let url = manifest.clipURL(for: sentence),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else { return false }
        timeline = WordTimeline(sentence: sentence, timedWords: entry.words)
        if let wordIndex {
            guard timeline.spans.indices.contains(wordIndex) else { return false }
            let span = timeline.spans[wordIndex]
            audioPlayer.currentTime = max(0, span.start - 0.03)
            sliceEnd = min(audioPlayer.duration, span.end + 0.05)
        }
        player = audioPlayer
        activeSource = ObjectIdentifier(audioPlayer)
        audioPlayer.enableRate = true
        audioPlayer.rate = isSlow ? 0.8 : 1
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.play()
        timingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateRecordingProgress() }
        }
        return true
    }

    private func updateRecordingProgress() {
        guard let player else { return }
        if let sliceEnd {
            if player.currentTime >= sliceEnd { finish() }
            return
        }
        if let index = timeline.index(at: player.currentTime) {
            currentWordIndex = index
            completedWordCount = index
        }
    }

    // MARK: On-device voice

    private func speak(_ utterance: AVSpeechUtterance) {
        utterance.voice = fallbackVoice
        utterance.rate = isSlow ? configuration.slowRate : configuration.normalRate
        utterance.pitchMultiplier = configuration.pitch
        activeSource = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
    }

    private static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let source = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard source == activeSource, isolatedWordIndex == nil else { return }
            let index = tokens.firstIndex { NSIntersectionRange($0.range, characterRange).length > 0 }
            currentWordIndex = index
            if let index { completedWordCount = index }
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let source = ObjectIdentifier(utterance)
        Task { @MainActor in
            if source == activeSource { finish() }
        }
    }

    // MARK: Shared

    /// Ends the current passage normally and tells whoever started it.
    private func finish() {
        let wasWord = isolatedWordIndex != nil
        let callback = completion
        stop()
        if !wasWord { completedWordCount = tokens.count }
        callback?()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in
                if began { self?.stop() } else { try? AVAudioSession.sharedInstance().setActive(true) }
            }
        }
    }
}

extension NarrationCoordinator: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let source = ObjectIdentifier(player)
        Task { @MainActor in
            if source == activeSource { finish() }
        }
    }
}
