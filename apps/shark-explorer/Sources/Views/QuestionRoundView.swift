import SwiftUI
import LearningUI
import Narration

/// Three picture questions; a wrong answer gives a clue and another try.
struct QuestionRoundView: View {
    let shark: SharkDefinition
    let onComplete: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var index = 0
    @State private var wrongChoiceIDs: Set<String> = []
    @State private var answeredCorrectly = false
    @State private var showingRetry = false
    @State private var orderedChoices: [[AnswerChoice]]

    init(shark: SharkDefinition, onComplete: @escaping () -> Void) {
        self.shark = shark
        self.onComplete = onComplete
        _orderedChoices = State(initialValue: QuizChoiceOrderer.order(for: shark.questions))
    }

    private var question: QuestionDefinition { shark.questions[index] }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(shark.questions.indices, id: \.self) { step in
                    Capsule()
                        .fill(step < index || (step == index && answeredCorrectly) ? theme.success : step == index ? .yellow : .white.opacity(0.25))
                        .frame(width: 54, height: 12)
                }
            }
            .accessibilityLabel("Question \(index + 1) of \(shark.questions.count)")

            ReadAlongView(sentences: question.prompt.sentences(for: game.readingMode), playbackID: question.id, finishTitle: nil, compact: true)

            HStack(spacing: 18) {
                ForEach(orderedChoices[index]) { choice in
                    AnswerTile(state: state(of: choice)) { choose(choice) } label: {
                        VStack(spacing: 8) {
                            KidArt(Self.artName(for: choice), fallback: choice.symbol, size: 68, style: .tile)
                            Text(choice.label)
                                .font(.kidHeadline)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(minHeight: 130)
                    }
                    .accessibilityLabel(choice.label)
                    .accessibilityIdentifier(choice.id == question.correctID ? "answer-correct" : "answer-other")
                }
            }

            HStack(spacing: 14) {
                if answeredCorrectly {
                    Text("⭐️").font(.system(size: 36))
                    Text(question.success).font(.kidHeadline)
                    Spacer(minLength: 8)
                    Button { advance() } label: {
                        Label(index + 1 < shark.questions.count ? "Next question" : "See your prize", systemImage: "arrow.right")
                    }
                    .buttonStyle(KidButtonStyle(tint: theme.success, compact: true))
                    .accessibilityIdentifier("next-question")
                } else if showingRetry {
                    Text("🔎").font(.system(size: 36))
                    Text(question.retry).font(.kidHeadline)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background((answeredCorrectly ? theme.success : .blue).opacity(answeredCorrectly || showingRetry ? 0.3 : 0), in: RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: answeredCorrectly)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingRetry)
        }
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
    }

    /// Choices that show the same thing share one picture.
    private static let sharedArt = [
        "trees": "tree", "forest": "tree", "climbs": "tree",
        "sky": "cloud", "night": "moon", "lunch": "bell",
        "fly": "wing", "flies": "wing"
    ]

    private static func artName(for choice: AnswerChoice) -> String {
        "choice-\(sharedArt[choice.id] ?? choice.id)"
    }

    private func state(of choice: AnswerChoice) -> AnswerState {
        if answeredCorrectly { return choice.id == question.correctID ? .correct : .dimmed }
        return wrongChoiceIDs.contains(choice.id) ? .wrong : .idle
    }

    private func choose(_ choice: AnswerChoice) {
        guard !answeredCorrectly else { return }
        if choice.id == question.correctID {
            answeredCorrectly = true
            game.recordQuizQuestion(for: shark, firstTry: wrongChoiceIDs.isEmpty)
            feedback.play(.correct)
            narration.play(question.success)
        } else {
            wrongChoiceIDs.insert(choice.id)
            showingRetry = true
            feedback.play(.wrong)
            narration.play(question.retry)
        }
    }

    private func advance() {
        guard answeredCorrectly else { return }
        narration.stop()
        guard index + 1 < shark.questions.count else {
            onComplete()
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            index += 1
            wrongChoiceIDs = []
            answeredCorrectly = false
            showingRetry = false
        }
    }
}
