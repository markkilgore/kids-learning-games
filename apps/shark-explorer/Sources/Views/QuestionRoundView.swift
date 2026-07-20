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

    private var question: QuestionDefinition { shark.questions[index] }

    var body: some View {
        ZStack {
            OceanBackdrop()
            VStack(spacing: 20) {
                HStack {
                    Text("Picture Question \(index + 1) of 3")
                        .font(.title.bold())
                    Spacer()
                    Button("Hear it again", systemImage: "speaker.wave.2.fill") { playPrompt() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 58)
                }

                ReadAlongView(sentences: question.prompt.sentences(for: game.readingMode))
                    .frame(maxHeight: 270)

                HStack(spacing: 22) {
                    ForEach(question.choices) { choice in
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
        .onAppear { playPrompt() }
        .onChange(of: index) { _, _ in playPrompt() }
    }

    private func playPrompt() {
        guard let sentence = question.prompt.sentences(for: game.readingMode).first else { return }
        narration.play(sentence)
    }

    private func choose(_ choice: AnswerChoice) {
        answeredCorrectly = choice.id == question.correctID
        feedback = answeredCorrectly ? question.success : question.retry
        narration.play(feedback ?? "")
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
