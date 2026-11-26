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

    static func challenge(for cat: CatDefinition, friendship: Int, difficulty: Int = 0) -> MathChallenge {
        var generator = SystemRandomNumberGenerator()
        return challenge(for: cat, friendship: friendship, difficulty: difficulty, using: &generator)
    }

    /// The skill a cat practises at this friendship level; difficulty never changes it.
    static func skill(for cat: CatDefinition, friendship: Int) -> EducationalSkill {
        let ids = cat.isInChapterTwo(at: friendship) ? CatContent.chapterTwoSkillIDs : CatContent.chapterOneSkillIDs
        let catIndex = CatContent.cats.firstIndex(of: cat) ?? 0
        let id = ids[(max(friendship, 0) + catIndex) % ids.count]
        return CatContent.skills.first { $0.id == id } ?? CatContent.skills[0]
    }

    /// Adaptive difficulty, limited to prompts that already have a recorded clip.
    ///
    /// Once a cat's last story page is showing, every puzzle shares that page's lead line, and the
    /// friendship levels `f`, `f + 6` and `f + 12` give the same skill with three different numbers
    /// (the seed cycles through 9 values while the skill cycles through 6). All three are in the
    /// recorded set that tools/lib/lines.mjs enumerates. They are ranked from smallest to largest
    /// numbers, and `difficulty` (-1, 0 or +1) moves one rank from the puzzle the rotation would
    /// normally give. Before the last story page there is only one recorded prompt, so it is used as is.
    static func variantFriendship(for cat: CatDefinition, friendship: Int, difficulty: Int) -> Int {
        let step = min(max(difficulty, SkillPracticeStats.difficultyRange.lowerBound), SkillPracticeStats.difficultyRange.upperBound)
        guard step != 0, friendship >= cat.lastPageFriendship else { return friendship }
        let skillCount = CatContent.chapterOneSkillIDs.count
        let ranked = (0..<3).map { friendship + $0 * skillCount }.sorted { lhs, rhs in
            let left = size(of: spec(for: cat, friendship: lhs)), right = size(of: spec(for: cat, friendship: rhs))
            return left == right ? lhs < rhs : left < right
        }
        let rank = ranked.firstIndex(of: friendship) ?? 0
        return ranked[min(max(rank + step, 0), ranked.count - 1)]
    }

    /// The prompt depends only on the cat, friendship and difficulty, so every prompt has a recorded clip
    /// (tools/lib/lines.mjs ports this). Only the order and choice of wrong answers is random.
    static func challenge<Generator: RandomNumberGenerator>(for cat: CatDefinition, friendship: Int, difficulty: Int = 0, using generator: inout Generator) -> MathChallenge {
        let puzzle = spec(for: cat, friendship: variantFriendship(for: cat, friendship: friendship, difficulty: difficulty))
        if puzzle.skill.id == "odd-even" {
            return MathChallenge(skill: puzzle.skill, prompt: puzzle.prompt, choices: [oddChoice, evenChoice], answer: puzzle.answer, icon: cat.storyIcon, visual: puzzle.visual, visualHint: puzzle.hint)
        }
        let answer = puzzle.answer, step = puzzle.step
        let wrong = [answer - 2 * step, answer - step, answer + step, answer + 2 * step].filter { $0 > 0 }.shuffled(using: &generator).prefix(2)
        return MathChallenge(skill: puzzle.skill, prompt: puzzle.prompt, choices: ([answer] + wrong).shuffled(using: &generator), answer: answer, icon: cat.storyIcon, visual: puzzle.visual, visualHint: puzzle.hint)
    }

    /// Everything about a puzzle except its shuffled choices.
    private struct Spec {
        let skill: EducationalSkill
        let prompt: String
        let answer: Int
        let visual: MathVisual
        let hint: String
        var step = 1
    }

    /// How big the numbers in a puzzle are, used to rank its recorded variants from easier to harder.
    private static func size(of puzzle: Spec) -> Int {
        switch puzzle.visual {
        case .count(let total), .pairs(let total), .subtract(let total, _): total
        case .add(let first, let second): first + second
        case .sequence(let numbers): numbers.last ?? 0
        }
    }

    private static func spec(for cat: CatDefinition, friendship: Int) -> Spec {
        let skill = skill(for: cat, friendship: friendship)
        let seed = max(1, (friendship + cat.name.count) % 9 + 1)
        let lead = cat.storyBeat(for: friendship).puzzleLead
        let icon = cat.storyIcon

        func make(_ prompt: String, _ answer: Int, _ visual: MathVisual, _ hint: String, step: Int = 1) -> Spec {
            Spec(skill: skill, prompt: prompt, answer: answer, visual: visual, hint: hint, step: step)
        }

        if cat.isInChapterTwo(at: friendship) {
            // Chapter two: sums and differences to 20, doubles, and counting by twos.
            switch skill.id {
            case "addition":
                let first = seed + 5, other = seed % 5 + 2
                return make("\(lead) \(cat.name) has \(first) \(noun(cat, count: first)) and finds \(other) more. How many now?", first + other, .add(first, other), "\(repeated(icon, count: first))  +  \(repeated(icon, count: other))")
            case "subtraction":
                let total = seed + 9, taken = seed % 5 + 2
                return make("\(lead) \(cat.name) counts \(total) \(noun(cat, count: total)). \(taken) are put away. How many stay?", total - taken, .subtract(total: total, taken: taken), "\(repeated(icon, count: total)), put away \(repeated(icon, count: taken))")
            case "doubles":
                let half = seed + 1
                return make("\(lead) \(cat.name) has \(half) \(noun(cat, count: half)) and finds \(half) more. What is double \(half)?", half * 2, .add(half, half), "\(repeated(icon, count: half))  +  \(repeated(icon, count: half))")
            case "odd-even":
                let number = seed + 7
                return make(
                    "\(lead) \(cat.name) finds \(number) \(noun(cat, count: number)). Is that odd or even?",
                    number.isMultiple(of: 2) ? evenChoice : oddChoice,
                    .pairs(number),
                    "\(repeated(icon, count: number)) in pairs"
                )
            default:
                let step = skill.id == "skip-2" ? 2 : 5
                let start = step == 2 ? 2 * (seed % 4 + 1) : 5 * (seed % 3 + 4)
                let shown = [start, start + step, start + 2 * step]
                return make(
                    "\(lead) help \(cat.name) count \(cat.storyItemPlural) by \(step == 2 ? "twos" : "fives"): \(shown[0]), \(shown[1]), \(shown[2]). What comes next?",
                    start + 3 * step,
                    .sequence(shown),
                    shown.map { "\(icon) \($0)" }.joined(separator: "   ") + "   \(icon) ?",
                    step: step
                )
            }
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
            return make(
                "\(lead) \(cat.name) finds \(number) \(noun(cat, count: number)). Is that odd or even?",
                number.isMultiple(of: 2) ? evenChoice : oddChoice,
                .pairs(number),
                "\(repeated(icon, count: number)) in pairs"
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
