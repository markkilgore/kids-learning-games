import SwiftUI
import LearningEngine
import Narration

public struct ReadAlongView: View {
    public let sentences: [String]
    public var vocabulary: Set<String> = []
    /// Changes when a parent swaps to a different passage while keeping this view on screen.
    /// This restarts the passage without triggering the old view's `onDisappear` stop handler.
    public var playbackID: String? = nil
    /// Label for the last control once every sentence has been heard; `nil` hides that control.
    public var finishTitle: String? = "Done"
    /// Tighter spacing for screens that also show answers below the passage.
    public var compact = false
    public var onFinished: () -> Void = {}

    public init(
        sentences: [String],
        vocabulary: Set<String> = [],
        playbackID: String? = nil,
        finishTitle: String? = "Done",
        compact: Bool = false,
        onFinished: @escaping () -> Void = {}
    ) {
        self.compact = compact
        self.sentences = sentences
        self.vocabulary = vocabulary
        self.playbackID = playbackID
        self.finishTitle = finishTitle
        self.onFinished = onFinished
    }

    @Environment(\.wordMarker) private var wordMarker
    @Environment(NarrationCoordinator.self) private var narration
    @State private var sentenceIndex = 0
    @State private var didFinish = false

    private var sentence: String { sentences[min(sentenceIndex, max(0, sentences.count - 1))] }

    public var body: some View {
        @Bindable var narration = narration
        VStack(spacing: compact ? 12 : 24) {
            if sentences.isEmpty {
                Text("This story is getting ready.")
                    .font(.largeTitle.bold())
            } else {
                if sentences.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(sentences.indices, id: \.self) { index in
                            Capsule()
                                .fill(index <= sentenceIndex ? Color.yellow : .white.opacity(0.25))
                                .frame(width: index == sentenceIndex ? 34 : 14, height: 10)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sentenceIndex)
                    .accessibilityLabel("Sentence \(sentenceIndex + 1) of \(sentences.count)")
                }

                WordFlowLayout(spacing: 6) {
                    ForEach(sentence.wordTokens) { token in
                        Button {
                            narration.speakWord(token.text, at: token.id, in: sentence)
                        } label: {
                            let mark = wordMarker?(token.text)
                            Text(token.text + sentence.punctuation(after: token.range))
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(wordColor(token))
                                .underline(mark == .decodable || mark == .featured, color: mark == .featured ? .yellow : .white.opacity(0.75))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(minWidth: 48, minHeight: 60)
                                .background(wordBackground(token), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    if mark == .heart {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.pink)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                                .scaleEffect(isSpeakingThisSentence && narration.currentWordIndex == token.id ? 1.08 : 1)
                                .animation(.spring(response: 0.22, dampingFraction: 0.7), value: narration.currentWordIndex)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Hear the word \(token.text)")
                    }
                }
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: compact ? 70 : 150, alignment: .top)

                if wordMarker != nil, !compact {
                    HStack(spacing: 18) {
                        Text("sound it out").underline(color: .white.opacity(0.75))
                        Text("new letters").underline(color: .yellow)
                        Label("heart word", systemImage: "heart.fill").labelStyle(.titleAndIcon)
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("reading-legend")
                }

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
                    let isLast = sentenceIndex + 1 >= sentences.count
                    if !isLast || finishTitle != nil {
                        control(
                            isLast ? (finishTitle ?? "") : "Next sentence",
                            systemImage: isLast ? "checkmark" : "arrow.right",
                            tint: .green
                        ) {
                            advance()
                        }
                        .opacity(narration.state == .idle ? 1 : 0.35)
                        .allowsHitTesting(narration.state == .idle)
                        .animation(.easeOut(duration: 0.2), value: narration.state == .idle)
                    }
                }
            }
        }
        .padding(compact ? 8 : 32)
        .onAppear { playCurrent() }
        .onDisappear {
            // Only silence this passage. A leaving screen is torn down after the next one has
            // started talking, and stopping everything would cut that new line off.
            if sentences.contains(narration.text) { narration.stop() }
        }
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
        Button(action: action) { Label(title, systemImage: systemImage) }
            .buttonStyle(KidButtonStyle(tint: tint, compact: true))
            .frame(maxWidth: .infinity)
    }

    private func index(of token: WordToken) -> Int { token.id }

    private var playPauseIcon: String {
        switch narration.state { case .playing: "pause.fill"; case .paused, .idle: "play.fill" }
    }

    private var playPauseTitle: String {
        switch narration.state { case .playing: "Pause"; case .paused: "Continue"; case .idle: "Play" }
    }

    /// The coordinator may be speaking something else (quiz feedback, a hint); only then-current text is highlighted.
    private var isSpeakingThisSentence: Bool { narration.text == sentence }

    private func wordColor(_ token: WordToken) -> Color {
        if isSpeakingThisSentence, narration.currentWordIndex == index(of: token) { return .navy }
        return .white
    }

    private func wordBackground(_ token: WordToken) -> Color {
        if isSpeakingThisSentence, narration.currentWordIndex == index(of: token) { return .yellow }
        if isSpeakingThisSentence, index(of: token) < narration.completedWordCount { return .white.opacity(0.18) }
        if vocabulary.contains(token.text.lowercased()) { return .cyan.opacity(0.22) }
        return .clear
    }
}

private extension Color {
    static let navy = Color(red: 0.02, green: 0.12, blue: 0.25)
}

public extension String {
    /// Sentence punctuation that directly follows a word, so the tappable words still read as a sentence or question.
    func punctuation(after range: NSRange) -> String {
        let text = self as NSString
        var index = NSMaxRange(range), result = ""
        while index < text.length {
            let character = text.substring(with: NSRange(location: index, length: 1))
            guard ".,!?;:’-".contains(character) else { break }
            result += character
            index += 1
        }
        return result
    }
}
