import LearningUI
import SwiftUI

/// The parent's view of Henry's progress: sharks completed, stars, topics explored, Ocean Words, and mission and quiz accuracy.
/// Adult-facing text only; nothing here is narrated.
struct SharkProgressSection: View {
    @Environment(GameStore.self) private var game
    @Environment(\.kidTheme) private var theme

    private var catalog: GameCatalog { ContentStore.shared.catalog }

    var body: some View {
        let quiz = game.quizTally()
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress", systemImage: "chart.bar.fill").font(.kidHeadline)
            Text("\(game.completedCount) of \(catalog.sharks.count) sharks completed • \(game.collectedWords.count) of \(catalog.vocabulary.count) Ocean Words collected • Quiz: \(Self.accuracy(firstTry: quiz.firstTry, retried: quiz.retried))")
            let numbers = game.roundTally(for: .math), words = game.roundTally(for: .words)
            Text("Mission rounds right first try • Numbers: \(Self.accuracy(firstTry: numbers.firstTry, retried: numbers.retried)) • Reading words: \(Self.accuracy(firstTry: words.firstTry, retried: words.retried))")
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                GridRow {
                    Text("Shark")
                    Text("Status")
                    Text("Topics explored")
                    Text("Quiz: right first try")
                }
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
                Divider().overlay(.white.opacity(0.3))
                ForEach(catalog.sharks) { shark in
                    let tally = game.quizTally(for: shark)
                    GridRow {
                        Text(shark.name).fontWeight(.bold)
                        Text(status(of: shark))
                        Text("\(shark.topics.filter { game.hasCompleted($0, for: shark) }.count) of \(shark.topics.count)")
                        Text(Self.accuracy(firstTry: tally.firstTry, retried: tally.retried))
                    }
                    .accessibilityElement(children: .combine)
                    if let note = Self.note(for: shark, firstTry: tally.firstTry, retried: tally.retried) {
                        GridRow {
                            Label(note, systemImage: "exclamationmark.bubble.fill")
                                .font(.kidLabel)
                                .foregroundStyle(.yellow)
                                .gridCellColumns(4)
                        }
                    }
                }
            }
            Text("Mission rounds are counting, comparing and one more or less to ten, and reading words from each shark’s sound-it-out sentences. A second and third star need nearly every round right first time.")
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
        }
        .font(.kidBody)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kidCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("parent-progress")
    }

    private func status(of shark: SharkDefinition) -> String {
        if game.completedSharks.contains(shark.id) { return "Completed, \(game.stars(for: shark)) of \(MissionChallenges.maxLevel) stars" }
        return game.isUnlocked(shark) ? "Unlocked" : "Locked"
    }

    static func accuracy(firstTry: Int, retried: Int) -> String {
        let total = firstTry + retried
        guard total > 0 else { return "—" }
        return "\(Int((Double(firstTry) / Double(total) * 100).rounded()))% (\(firstTry) of \(total))"
    }

    /// A plain note when a shark's questions often needed another try.
    static func note(for shark: SharkDefinition, firstTry: Int, retried: Int) -> String? {
        guard firstTry + retried >= 3, retried > firstTry else { return nil }
        return "Henry often needed a second try on the \(shark.name) questions. Re-reading its topics together can help."
    }
}
