import SwiftUI
import LearningEngine
import Narration

public struct ReadAlongView: View {
    public let sentences: [String]
    public var vocabulary: Set<String> = []
    /// Changes when a parent swaps to a different passage while keeping this view on screen.
    /// This restarts the passage without triggering the old view's `onDisappear` stop handler.
    public var playbackID: String? = nil
    public var onFinished: () -> Void = {}

    public init(
        sentences: [String],
        vocabulary: Set<String> = [],
        playbackID: String? = nil,
        onFinished: @escaping () -> Void = {}
    ) {
        self.sentences = sentences
        self.vocabulary = vocabulary
        self.playbackID = playbackID
        self.onFinished = onFinished
    }

    @Environment(NarrationCoordinator.self) private var narration
    @State private var sentenceIndex = 0
    @State private var didFinish = false

    private var sentence: String { sentences[min(sentenceIndex, max(0, sentences.count - 1))] }

    public var body: some View {
        @Bindable var narration = narration
        VStack(spacing: 24) {
            if sentences.isEmpty {
                Text("This story is getting ready.")
                    .font(.largeTitle.bold())
            } else {
                Text("Sentence \(sentenceIndex + 1) of \(sentences.count)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))

                WordFlowLayout(spacing: 12) {
                    ForEach(sentence.wordTokens) { token in
                        Button {
                            narration.speakWord(token.text, at: token.id, in: sentence)
                        } label: {
                            Text(token.text)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(wordColor(token))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 4)
                                .background(wordBackground(token), in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hear the word \(token.text)")
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 150, alignment: .top)

                HStack(spacing: 18) {
                    control("Replay", systemImage: "speaker.wave.2.fill", tint: .blue) {
                        playCurrent()
                    }
                    control(playPauseTitle, systemImage: playPauseIcon, tint: .blue) {
                        if narration.state == .idle { playCurrent() } else { narration.togglePause() }
                    }
                    control(
                        narration.isSlow ? "Normal speed" : "Slow speed",
                        systemImage: "tortoise.fill",
                        tint: narration.isSlow ? .orange : .teal
                    ) {
                        narration.setSlow(!narration.isSlow)
                    }
                    control(
                        sentenceIndex + 1 < sentences.count ? "Next sentence" : "Done",
                        systemImage: sentenceIndex + 1 < sentences.count ? "arrow.right" : "checkmark",
                        tint: .green
                    ) {
                        advance()
                    }
                    .opacity(narration.state == .idle ? 1 : 0)
                    .allowsHitTesting(narration.state == .idle)
                }
            }
        }
        .padding(32)
        .onAppear { playCurrent() }
        .onDisappear { narration.stop() }
        .onChange(of: playbackID) { _, _ in
            let needsSentenceReset = sentenceIndex != 0
            sentenceIndex = 0
            didFinish = false
            if !needsSentenceReset { playCurrent() }
        }
        .onChange(of: sentenceIndex) { _, _ in playCurrent() }
    }

    private func playCurrent() {
        guard !sentences.isEmpty else { return }
        let playingIndex = sentenceIndex
        narration.play(sentence) {
            guard playingIndex == sentenceIndex, sentenceIndex + 1 < sentences.count else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard playingIndex == sentenceIndex else { return }
                advance()
            }
        }
    }

    private func advance() {
        guard sentenceIndex + 1 < sentences.count else {
            guard !didFinish else { return }
            didFinish = true
            onFinished()
            return
        }
        sentenceIndex += 1
    }

    private func control(
        _ title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .frame(maxWidth: .infinity)
    }

    private func index(of token: WordToken) -> Int { token.id }

    private var playPauseIcon: String {
        switch narration.state { case .playing: "pause.fill"; case .paused, .idle: "play.fill" }
    }

    private var playPauseTitle: String {
        switch narration.state { case .playing: "Pause"; case .paused: "Continue"; case .idle: "Play" }
    }

    private func wordColor(_ token: WordToken) -> Color {
        if narration.currentWordIndex == index(of: token) { return .navy }
        return .white
    }

    private func wordBackground(_ token: WordToken) -> Color {
        if narration.currentWordIndex == index(of: token) { return .yellow }
        if index(of: token) < narration.completedWordCount { return .white.opacity(0.18) }
        if vocabulary.contains(token.text.lowercased()) { return .cyan.opacity(0.22) }
        return .clear
    }
}

private extension Color {
    static let navy = Color(red: 0.02, green: 0.12, blue: 0.25)
}
