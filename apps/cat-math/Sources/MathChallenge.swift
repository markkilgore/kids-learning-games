import Foundation
import LearningEngine

/// The picture that goes with a puzzle, drawn as objects a child can tap and count.
enum MathVisual: Equatable {
    case count(Int)
    case add(Int, Int)
    case subtract(total: Int, taken: Int)
    case pairs(Int)
    case sequence([Int])
}

struct MathChallenge: Equatable {
    let skill: EducationalSkill
    let prompt: String
    let choices: [Int]
    let answer: Int
    let icon: String
    let visual: MathVisual
    /// Plain-text version of the picture, for VoiceOver.
    let visualHint: String

    /// Odd-or-even puzzles answer with words; every other puzzle answers with a number.
    func label(for choice: Int) -> String {
        guard skill.id == "odd-even" else { return "\(choice)" }
        return choice == MathChallengeFactory.oddChoice ? "Odd" : "Even"
    }
}

enum MathChallengeFactory {
    static let oddChoice = 1
    static let evenChoice = 2

    static func challenge(for cat: CatDefinition, friendship: Int) -> MathChallenge {
        var generator = SystemRandomNumberGenerator()
        return challenge(for: cat, friendship: friendship, using: &generator)
    }

    /// The prompt depends only on the cat and friendship, so every prompt has a recorded clip
    /// (tools/lib/lines.mjs ports this). Only the order and choice of wrong answers is random.
    static func challenge<Generator: RandomNumberGenerator>(for cat: CatDefinition, friendship: Int, using generator: inout Generator) -> MathChallenge {
        let skills = CatAppConfiguration.value.enabledSkills
        let catIndex = CatContent.cats.firstIndex(of: cat) ?? 0
        let skill = skills[(friendship + catIndex) % skills.count]
        let seed = max(1, (friendship + cat.name.count) % 9 + 1)
        let lead = cat.storyBeat(for: friendship).puzzleLead
        let icon = cat.storyIcon

        func make(_ prompt: String, _ answer: Int, _ visual: MathVisual, _ hint: String, step: Int = 1) -> MathChallenge {
            let wrong = [answer - 2 * step, answer - step, answer + step, answer + 2 * step].filter { $0 > 0 }.shuffled(using: &generator).prefix(2)
            return MathChallenge(skill: skill, prompt: prompt, choices: ([answer] + wrong).shuffled(using: &generator), answer: answer, icon: icon, visual: visual, visualHint: hint)
        }

        switch skill.id {
        case "addition":
            let other = (seed % 4) + 1
            return make("\(lead) \(cat.name) has \(seed) \(noun(cat, count: seed)) and finds \(other) more. How many now?", seed + other, .add(seed, other), "\(repeated(icon, count: seed))  +  \(repeated(icon, count: other))")
        case "subtraction":
            let total = seed + 4, taken = min(3, seed)
            return make("\(lead) \(cat.name) counts \(total) \(noun(cat, count: total)). \(taken) \(taken == 1 ? "is" : "are") put away. How many stay?", total - taken, .subtract(total: total, taken: taken), "\(repeated(icon, count: total)), put away \(repeated(icon, count: taken))")
        case "odd-even":
            let number = seed + 3
            return MathChallenge(
                skill: skill,
                prompt: "\(lead) \(cat.name) finds \(number) \(noun(cat, count: number)). Is that odd or even?",
                choices: [oddChoice, evenChoice],
                answer: number.isMultiple(of: 2) ? evenChoice : oddChoice,
                icon: icon,
                visual: .pairs(number),
                visualHint: "\(repeated(icon, count: number)) in pairs"
            )
        case "skip-5", "skip-10":
            let step = skill.id == "skip-5" ? 5 : 10
            let start = step * (seed % 3 + 1)
            let shown = [start, start + step, start + 2 * step]
            return make(
                "\(lead) help \(cat.name) count \(cat.storyItemPlural) by \(step == 5 ? "fives" : "tens"): \(shown[0]), \(shown[1]), \(shown[2]). What comes next?",
                start + 3 * step,
                .sequence(shown),
                shown.map { "\(icon) \($0)" }.joined(separator: "   ") + "   \(icon) ?",
                step: step
            )
        default:
            return make("\(lead) how many \(noun(cat, count: seed)) did \(cat.name) find?", seed, .count(seed), repeated(icon, count: seed))
        }
    }

    private static func repeated(_ symbol: String, count: Int) -> String {
        Array(repeating: symbol, count: count).joined(separator: " ")
    }

    private static func noun(_ cat: CatDefinition, count: Int) -> String {
        count == 1 ? cat.storyItem : cat.storyItemPlural
    }
}
