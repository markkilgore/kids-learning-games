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
        switch skill.id {
        case "addition":
            let other = (seed % 4) + 1
            return make(skill, "\(cat.name) has \(seed) treats and finds \(other) more. How many treats now?", seed + other, "\(icons(seed))  +  \(icons(other))")
        case "subtraction":
            let total = seed + 4, taken = min(3, seed)
            return make(skill, "\(cat.name) has \(total) toy mice. \(taken) roll away. How many stay?", total - taken, "\(icons(total))\nTake away \(icons(taken))")
        case "odd-even":
            let number = seed + 3, answer = number.isMultiple(of: 2) ? 2 : 1
            return MathChallenge(skill: skill, prompt: "Is \(number) odd or even? Choose 1 for odd or 2 for even.", choices: [1, 2], answer: answer, visualHint: icons(number))
        case "skip-5":
            return make(skill, "Count by fives: 5, 10, 15, what comes next?", 20, "🐾 5   🐾 10   🐾 15   🐾 ?")
        case "skip-10":
            return make(skill, "Count by tens: 10, 20, 30, what comes next?", 40, "🧶 10   🧶 20   🧶 30   🧶 ?")
        default:
            return make(skill, "How many yarn balls did \(cat.name) find?", seed, icons(seed))
        }
    }

    private static func make(_ skill: EducationalSkill, _ prompt: String, _ answer: Int, _ hint: String) -> MathChallenge {
        let alternatives = Array(Set([max(0, answer - 1), answer, answer + 1])).sorted()
        return MathChallenge(skill: skill, prompt: prompt, choices: alternatives, answer: answer, visualHint: hint)
    }

    private static func icons(_ count: Int) -> String { Array(repeating: "🧶", count: min(count, 14)).joined(separator: " ") }
}
