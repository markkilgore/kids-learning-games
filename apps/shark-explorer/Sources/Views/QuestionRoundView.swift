import SwiftUI
import LearningUI
import Narration

struct QuestionRoundView: View {
    let shark: SharkDefinition
    let onComplete: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @State private var index = 0
    @State private var feedback: String?
    @State private var answeredCorrectly = false
    @State private var orderedChoices: [[AnswerChoice]]

    init(shark: SharkDefinition, onComplete: @escaping () -> Void) {
        self.shark = shark
        self.onComplete = onComplete
        _orderedChoices = State(initialValue: QuizChoiceOrderer.order(for: shark.questions))
    }

    private var question: QuestionDefinition { shark.questions[index] }
    private var displayedSentences: [String] {
        feedback.map { [$0] } ?? question.prompt.sentences(for: game.readingMode)
    }
    private var displayedSentenceID: String { "\(question.id)-\(feedback ?? "prompt")" }

    var body: some View {
        ZStack {
            OceanBackdrop()
            VStack(spacing: 20) {
                HStack {
                    Text("Picture Question \(index + 1) of \(shark.questions.count)")
                        .font(.title.bold())
                    Spacer()
                    Button("Hear it again", systemImage: "speaker.wave.2.fill") { playPrompt() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 58)
                }

                ReadAlongView(sentences: displayedSentences, playbackID: displayedSentenceID)
                    .frame(maxHeight: 270)

                HStack(spacing: 22) {
                    ForEach(orderedChoices[index]) { choice in
                        Button { choose(choice) } label: {
                            VStack(spacing: 12) {
                                Text(choice.symbol).font(.system(size: 76))
                                Text(choice.label)
                                    .font(.title2.weight(.black))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 26))
                            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.25), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .disabled(answeredCorrectly)
                        .accessibilityLabel(choice.label)
                    }
                }

                if let feedback {
                    HStack {
                        Text(answeredCorrectly ? "⭐️" : "🔎")
                        Text(feedback).font(.title2.bold())
                        Spacer()
                        if answeredCorrectly {
                            Button(index + 1 < shark.questions.count ? "Next question" : "Open Shark Book") { advance() }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .font(.headline)
                        }
                    }
                    .padding(20)
                    .background((answeredCorrectly ? Color.green : Color.blue).opacity(0.28), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(32)
            .foregroundStyle(.white)
        }
    }

    private func playPrompt() {
        guard let sentence = displayedSentences.first else { return }
        narration.play(sentence)
    }

    private func choose(_ choice: AnswerChoice) {
        answeredCorrectly = choice.id == question.correctID
        feedback = answeredCorrectly ? question.success : question.retry
    }

    private func advance() {
        if index + 1 < shark.questions.count {
            index += 1
            feedback = nil
            answeredCorrectly = false
        } else {
            narration.stop()
            onComplete()
        }
    }
}
