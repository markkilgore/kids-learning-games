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
    /// A line waiting for its pause to pass before it starts.
    private var pending: Task<Void, Never>?
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

    /// Speaks `sentence` after a short pause, so it does not talk over a sound effect that has just started.
    public func play(_ sentence: String, after delay: TimeInterval, completion: (() -> Void)? = nil) {
        stop()
        schedule(after: delay) { [weak self] in self?.play(sentence, completion: completion) }
    }

    /// Speaks several lines in order with a breath between them. Starting anything else cancels the rest.
    public func playSequence(_ lines: [String], gap: TimeInterval = 0.4, completion: (() -> Void)? = nil) {
        let lines = lines.filter { !$0.isEmpty }
        guard let first = lines.first else {
            completion?()
            return
        }
        let rest = Array(lines.dropFirst())
        play(first) { [weak self] in
            guard !rest.isEmpty else {
                completion?()
                return
            }
            self?.schedule(after: gap) { self?.playSequence(rest, gap: gap, completion: completion) }
        }
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.pending = nil
            work()
        }
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

    /// Speaks a run of words from `sentence` (one short sentence out of a longer recorded line), cut from the
    /// line's own recording so the voice stays the same.
    public func speakWords(_ words: Range<Int>, in sentence: String, completion: (() -> Void)? = nil) {
        stop()
        let allTokens = sentence.wordTokens
        guard !words.isEmpty, allTokens.indices.contains(words.lowerBound), allTokens.indices.contains(words.upperBound - 1) else {
            completion?()
            return
        }
        text = sentence
        tokens = allTokens
        self.completion = completion
        guard settings.voiceEnabled else {
            finish()
            return
        }
        isolatedWordIndex = words.lowerBound
        state = .playing
        if startRecording(for: sentence, from: words.lowerBound, through: words.upperBound - 1) { return }
        let start = allTokens[words.lowerBound].range.location
        let last = allTokens[words.upperBound - 1].range
        speak(AVSpeechUtterance(string: (sentence as NSString).substring(with: NSRange(location: start, length: last.location + last.length - start))))
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
        pending?.cancel()
        pending = nil
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

    private func startRecording(for sentence: String, from wordIndex: Int?, through lastWordIndex: Int? = nil) -> Bool {
        guard let entry = manifest.entry(for: sentence),
              let url = manifest.clipURL(for: sentence),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else { return false }
        timeline = WordTimeline(sentence: sentence, timedWords: entry.words)
        if let wordIndex {
            let lastIndex = lastWordIndex ?? wordIndex
            guard timeline.spans.indices.contains(wordIndex), timeline.spans.indices.contains(lastIndex) else { return false }
            let span = timeline.spans[wordIndex]
            audioPlayer.currentTime = max(0, span.start - 0.03)
            sliceEnd = min(audioPlayer.duration, timeline.spans[lastIndex].end + 0.05)
        }
        player = audioPlayer
        activeSource = ObjectIdentifier(audioPlayer)
        audioPlayer.enableRate = true
        audioPlayer.rate = isSlow ? 0.8 : 1
        audioPlayer.delegate = self
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

    /// Switching the audio session on can block for a moment, so it happens off the main thread, once,
    /// before any clip plays. Players then start without having to activate it themselves.
    private nonisolated static func activateSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        Self.activateSession()
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in
                if began { self?.stop() } else { Self.activateSession() }
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
