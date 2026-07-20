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
    private var timedWords: [TimedWord] = []
    private var completion: (() -> Void)?
    private var generation = UUID()
    private var activeUtteranceText = ""
    private var isolatedWordIndex: Int?
    private let configuration: NarrationSettings
    private let manifest: AudioManifest

    public private(set) var text = ""
    public private(set) var tokens: [WordToken] = []
    public private(set) var currentWordIndex: Int?
    public private(set) var completedWordCount = 0
    public private(set) var state: PlaybackState = .idle
    public var isSlow = false

    public init(configuration: NarrationSettings = NarrationSettings(), bundle: Bundle = .main) {
        self.configuration = configuration
        manifest = AudioManifest(bundle: bundle, resourceName: configuration.bundledManifestName)
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    public func play(_ sentence: String, completion: (() -> Void)? = nil) {
        stop()
        generation = UUID()
        text = sentence
        tokens = sentence.wordTokens
        currentWordIndex = nil
        completedWordCount = 0
        state = .playing
        self.completion = completion
        activeUtteranceText = sentence
        isolatedWordIndex = nil

        if let entry = manifest.entry(for: sentence), playBundled(entry) {
            return
        }

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: configuration.language)
        utterance.rate = isSlow ? configuration.slowRate : configuration.normalRate
        utterance.pitchMultiplier = configuration.pitch
        utterance.postUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    public func speakWord(_ word: String, at index: Int, in sentence: String) {
        stop()
        text = sentence
        tokens = sentence.wordTokens
        currentWordIndex = index
        completedWordCount = index
        state = .playing
        activeUtteranceText = word
        isolatedWordIndex = index

        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: configuration.language)
        utterance.rate = isSlow ? configuration.slowRate : configuration.normalRate
        synthesizer.speak(utterance)
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
                return
            }
            if synthesizer.pauseSpeaking(at: .word) { state = .paused }
        case .paused:
            if let player {
                player.play()
                state = .playing
                return
            }
            if synthesizer.continueSpeaking() { state = .playing }
        case .idle:
            replay()
        }
    }

    public func setSlow(_ slow: Bool) {
        isSlow = slow
        if state != .idle { replay() }
    }

    public func stop() {
        generation = UUID()
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        timingTimer?.invalidate()
        timingTimer = nil
        timedWords = []
        isolatedWordIndex = nil
        completion = nil
        currentWordIndex = nil
        completedWordCount = 0
        state = .idle
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let spokenText = utterance.speechString
        Task { @MainActor in
            guard spokenText == activeUtteranceText else { return }
            if let isolatedWordIndex {
                currentWordIndex = isolatedWordIndex
                return
            }
            let index = tokens.firstIndex { NSIntersectionRange($0.range, characterRange).length > 0 }
            currentWordIndex = index
            if let index { completedWordCount = index }
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let spokenText = utterance.speechString
        Task { @MainActor in
            guard spokenText == activeUtteranceText else { return }
            if isolatedWordIndex == nil { completedWordCount = tokens.count }
            currentWordIndex = nil
            state = .idle
            let callback = completion
            completion = nil
            callback?()
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let spokenText = utterance.speechString
        Task { @MainActor in
            if spokenText == activeUtteranceText { state = .idle }
        }
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func playBundled(_ entry: AudioManifestEntry) -> Bool {
        let base = (entry.file as NSString).deletingPathExtension
        let ext = (entry.file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.main.url(forResource: base, withExtension: ext),
              let audioPlayer = try? AVAudioPlayer(contentsOf: url) else { return false }
        player = audioPlayer
        timedWords = entry.words
        audioPlayer.enableRate = true
        audioPlayer.rate = isSlow ? 0.75 : 1
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.play()
        timingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateBundledTiming() }
        }
        return true
    }

    private func updateBundledTiming() {
        guard let player else { return }
        let time = player.currentTime
        if let index = timedWords.firstIndex(where: { time >= $0.start && time < $0.end }) {
            currentWordIndex = index
            completedWordCount = index
        }
    }
}

extension NarrationCoordinator: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            timingTimer?.invalidate()
            timingTimer = nil
            self.player = nil
            completedWordCount = tokens.count
            currentWordIndex = nil
            state = .idle
            let callback = completion
            completion = nil
            callback?()
        }
    }
}
