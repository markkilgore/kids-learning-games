import Foundation
import LearningEngine

struct MathChallenge: Equatable {
    let skill: EducationalSkill
    let prompt: String
    let choices: [Int]
    let answer: Int
    let visualHint: String
}

enum MathChallengeFactory {
    static func challenge(for cat: CatDefinition, friendship: Int) -> MathChallenge {
        let skills = CatAppConfiguration.value.enabledSkills
        let catIndex = CatContent.cats.firstIndex(of: cat) ?? 0
        let skill = skills[(friendship + catIndex) % skills.count]
        let seed = max(1, (friendship + cat.name.count) % 9 + 1)
        let story = cat.storyBeat(for: friendship)
        switch skill.id {
        case "addition":
            let other = (seed % 4) + 1
            return make(skill, "\(story.puzzleLead) \(cat.name) has \(seed) \(noun(cat, count: seed)) and finds \(other) more. How many now?", seed + other, "\(repeated(cat.storyIcon, count: seed))  +  \(repeated(cat.storyIcon, count: other))")
        case "subtraction":
            let total = seed + 4, taken = min(3, seed)
            return make(skill, "\(story.puzzleLead) \(cat.name) counts \(total) \(noun(cat, count: total)). \(taken) are put away. How many stay?", total - taken, "\(repeated(cat.storyIcon, count: total))\nPut away \(repeated(cat.storyIcon, count: taken))")
        case "odd-even":
            let number = seed + 3, answer = number.isMultiple(of: 2) ? 2 : 1
            return MathChallenge(skill: skill, prompt: "\(story.puzzleLead) \(cat.name) finds \(number) \(noun(cat, count: number)). Is that odd or even? Choose 1 for odd or 2 for even.", choices: [1, 2], answer: answer, visualHint: paired(cat.storyIcon, count: number))
        case "skip-5":
            return make(skill, "\(story.puzzleLead) help \(cat.name) count \(cat.storyItemPlural) by fives: 5, 10, 15. What comes next?", 20, "\(cat.storyIcon) 5   \(cat.storyIcon) 10   \(cat.storyIcon) 15   \(cat.storyIcon) ?")
        case "skip-10":
            return make(skill, "\(story.puzzleLead) help \(cat.name) count \(cat.storyItemPlural) by tens: 10, 20, 30. What comes next?", 40, "\(cat.storyIcon) 10   \(cat.storyIcon) 20   \(cat.storyIcon) 30   \(cat.storyIcon) ?")
        default:
            return make(skill, "\(story.puzzleLead) how many \(noun(cat, count: seed)) did \(cat.name) find?", seed, repeated(cat.storyIcon, count: seed))
        }
    }

    private static func make(_ skill: EducationalSkill, _ prompt: String, _ answer: Int, _ hint: String) -> MathChallenge {
        let alternatives = Array(Set([max(0, answer - 1), answer, answer + 1])).sorted()
        return MathChallenge(skill: skill, prompt: prompt, choices: alternatives, answer: answer, visualHint: hint)
    }

    private static func repeated(_ symbol: String, count: Int) -> String {
        Array(repeating: symbol, count: min(count, 14)).joined(separator: " ")
    }

    private static func paired(_ symbol: String, count: Int) -> String {
        let pairs = Array(repeating: "\(symbol)\(symbol)", count: count / 2)
        return (pairs + (count.isMultiple(of: 2) ? [] : [symbol])).joined(separator: "  ")
    }

    private static func noun(_ cat: CatDefinition, count: Int) -> String {
        count == 1 ? cat.storyItem : cat.storyItemPlural
    }
}
