import LearningEngine
import LearningUI
import SwiftUI

/// The parent's view of each skill: how often it was practised, first-try accuracy, and the current difficulty.
/// Adult-facing text only; nothing here is narrated.
struct CatProgressSection: View {
    @Environment(CatGameStore.self) private var game
    @Environment(\.kidTheme) private var theme

    private let skills = CatAppConfiguration.value.enabledSkills

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress", systemImage: "chart.bar.fill").font(.kidHeadline)
            if skills.allSatisfy({ game.stats(for: $0).attempts == 0 }) {
                Text("No puzzles answered yet. Each skill’s record appears here once Kate starts playing.")
                    .foregroundStyle(theme.mutedInk)
            }
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                GridRow {
                    Text("Skill")
                    Text("Practised")
                    Text("Right first try")
                    Text("Difficulty")
                    Text("Last practised")
                }
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
                Divider()
                ForEach(skills) { skill in
                    let stats = game.stats(for: skill)
                    GridRow {
                        Text(skill.displayName).fontWeight(.bold)
                        Text(stats.attempts == 1 ? "1 time" : "\(stats.attempts) times")
                        Text(Self.accuracy(stats))
                        Text(Self.difficulty(stats))
                        Text(stats.lastPractised.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    }
                    .accessibilityElement(children: .combine)
                    if let note = Self.note(stats) {
                        GridRow {
                            Label(note, systemImage: "exclamationmark.bubble.fill")
                                .font(.kidLabel)
                                .foregroundStyle(theme.secondary)
                                .gridCellColumns(5)
                        }
                    }
                }
            }
            Text("Puzzles step one level harder after \(SkillPracticeStats.stepUpAfter) in a row are right first time, and one level easier after \(SkillPracticeStats.stepDownAfter) misses without a first-try success. Easier and harder levels use smaller or bigger numbers once a cat’s whole story is unlocked.")
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
        }
        .font(.kidBody)
        .tint(theme.primary)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kidCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("parent-progress")
    }

    static func accuracy(_ stats: SkillPracticeStats) -> String {
        guard let accuracy = stats.firstTryAccuracy else { return "—" }
        return "\(Int((accuracy * 100).rounded()))% (\(stats.firstTryCorrect) of \(stats.attempts))"
    }

    static func difficulty(_ stats: SkillPracticeStats) -> String {
        switch stats.difficulty {
        case ..<0: "Easier"
        case 1...: "Harder"
        default: "Standard"
        }
    }

    /// A plain note when a skill needs a parent's help, or nil when it is going fine.
    static func note(_ stats: SkillPracticeStats) -> String? {
        guard stats.needsHelp else { return nil }
        let misses = stats.wrongAnswers == 1 ? "1 wrong answer" : "\(stats.wrongAnswers) wrong answers"
        return stats.difficulty < 0
            ? "Kate is finding this tricky (\(misses) so far), so puzzles have stepped back to smaller numbers. Counting the picture together can help."
            : "Kate often needs a second try here (\(misses) so far). Counting the picture together can help."
    }
}
