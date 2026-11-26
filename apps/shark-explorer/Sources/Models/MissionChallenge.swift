import Foundation
import LearningEngine

/// One round of a mission: a spoken question and two or three answers floating in the water.
struct MissionChallenge: Equatable {
    enum Area: String, CaseIterable { case math, words }

    enum Choice: Equatable {
        /// A group of the mission's own picture (plankton, crabs, tuna) to count.
        case group(Int)
        case numeral(Int)
        case word(String)
        /// A whole short sentence to read.
        case phrase(String)
    }

    /// Words to play from a longer recorded line, after the spoken instruction.
    struct Echo: Equatable {
        let line: String
        let words: Range<Int>
    }

    let area: Area
    /// What the narrator says.
    let spoken: String
    /// What is written over the game. Word rounds do not show the word, so it has to be read, not matched.
    let shown: String
    let choices: [Choice]
    /// Index of the right choice.
    let answer: Int
    /// For sentence rounds: the sentence itself, played from its line's recording after `spoken`.
    var echo: Echo?
}

/// Builds each mission's rounds from kindergarten skills: counting and comparing to ten, one more and one less,
/// and reading the sound-it-out and heart words from that shark's own sentences.
enum MissionChallenges {
    /// Levels one to three earn the yellow stars; four and five are the super stars.
    static let plainStars = 3
    static let maxLevel = 5
    static let listenPrompt = "Tap the word you hear."
    static let listenSentencePrompt = "Tap the words you hear."
    static func plusLine(_ first: Int, _ second: Int) -> String { "What is \(first) plus \(second)?" }
    static func minusLine(_ total: Int, _ taken: Int) -> String { "What is \(total) take away \(taken)?" }

    static func countLine(_ count: Int) -> String { "Tap the group of \(count)." }
    static func numeralLine(_ number: Int) -> String { "Tap the number \(number)." }
    static let moreLine = "Which group has more?"
    static let fewerLine = "Which group has fewer?"
    static func oneMoreLine(_ number: Int) -> String { "What is one more than \(number)?" }
    static func oneLessLine(_ number: Int) -> String { "What is one less than \(number)?" }
    static func wordLine(_ word: String) -> String { "Tap the word: \(word)." }

    /// A new star needs nearly every round right on the first tap. The first star only needs a finished mission.
    static func earnsStar(level: Int, firstTry: Int, rounds: Int) -> Bool {
        level <= 1 || firstTry >= rounds - 1
    }

    struct ReadingWords: Equatable {
        var decodable: [String] = []
        var heart: [String] = []
    }

    /// The words Henry can read in these sharks' sound-it-out sentences, two letters or longer.
    static func readingWords(in sharks: [SharkDefinition], reading: SharkReading) -> ReadingWords {
        var result = ReadingWords()
        var seen: Set<String> = []
        for shark in sharks {
            let narratives = [shark.discover] + shark.topics.map(\.narration)
            for sentence in narratives.flatMap({ $0.decodable ?? [] }) {
                for word in sentence.wordTokens.map({ $0.text.lowercased() }) where word.count >= 2 && seen.insert(word).inserted {
                    switch reading.mark(word) {
                    case .heart: result.heart.append(word)
                    case .decodable, .featured: result.decodable.append(word)
                    case nil: break
                    }
                }
            }
        }
        return result
    }

    /// Every line a mission round can speak, so each one gets a recording. Kept in step with `challengeLines` in tools/lib/lines.mjs.
    static func allSpokenLines(sharks: [SharkDefinition], reading: SharkReading) -> [String] {
        let words = readingWords(in: sharks, reading: reading)
        var lines = (1...10).map(countLine) + (1...20).map(numeralLine) + [moreLine, fewerLine]
            + (1...19).map(oneMoreLine) + (2...20).map(oneLessLine)
            + (words.decodable + words.heart).map(wordLine)
        for first in 1...9 { lines += (1...(10 - first)).map { plusLine(first, $0) } }
        for total in 2...10 { lines += (1..<total).map { minusLine(total, $0) } }
        return lines + [listenSentencePrompt]
    }

    /// A short sentence inside one of a shark's sound-it-out lines.
    struct Sentence: Equatable {
        let text: String
        let echo: MissionChallenge.Echo
        var wordCount: Int { echo.words.count }
        var words: [String] { text.wordTokens.map { $0.text.lowercased() } }
    }

    /// The sound-it-out lines of these sharks, split into their sentences of three to six words.
    static func sentences(in sharks: [SharkDefinition]) -> [Sentence] {
        var result: [Sentence] = []
        var seen: Set<String> = []
        for shark in sharks {
            let narratives = [shark.discover] + shark.topics.map(\.narration)
            for line in narratives.flatMap({ $0.decodable ?? [] }) {
                let tokens = line.wordTokens
                let whole = line as NSString
                var start = 0
                for (index, token) in tokens.enumerated() {
                    let end = token.range.location + token.range.length
                    let gap = index + 1 < tokens.count ? whole.substring(with: NSRange(location: end, length: tokens[index + 1].range.location - end)) : "."
                    guard gap.contains(where: { ".!?".contains($0) }) else { continue }
                    let from = tokens[start].range.location
                    let stop = gap.firstIndex(where: { ".!?".contains($0) }).map { gap.distance(from: gap.startIndex, to: $0) + 1 } ?? 0
                    let text = whole.substring(with: NSRange(location: from, length: min(end + stop, whole.length) - from))
                    let words = start..<(index + 1)
                    start = index + 1
                    // A sentence must read the same on its own as it does inside its line.
                    guard (3...6).contains(words.count), text.wordTokens.map(\.text) == tokens[words].map(\.text), seen.insert(text.lowercased()).inserted else { continue }
                    result.append(Sentence(text: text, echo: MissionChallenge.Echo(line: line, words: words)))
                }
            }
        }
        return result
    }

    static func rounds(for shark: SharkDefinition, level: Int, sharks: [SharkDefinition], reading: SharkReading) -> [MissionChallenge] {
        var generator = SystemRandomNumberGenerator()
        return rounds(for: shark, level: level, sharks: sharks, reading: reading, using: &generator)
    }

    /// Number rounds and word rounds take turns, starting with numbers.
    static func rounds<Generator: RandomNumberGenerator>(
        for shark: SharkDefinition,
        level: Int,
        sharks: [SharkDefinition],
        reading: SharkReading,
        using generator: inout Generator
    ) -> [MissionChallenge] {
        let level = min(max(level, 1), maxLevel)
        let pool = readingWords(in: sharks, reading: reading)
        let mine = readingWords(in: [shark], reading: reading)
        let mathKinds = MathKind.kinds(for: level).shuffled(using: &generator)
        var targets = mine.decodable.filter { $0.count >= 3 }.shuffled(using: &generator)
        var hearts = mine.heart.shuffled(using: &generator)
        let heartPool = reading.heartWords.filter { $0.count >= 2 }
        let sentencePool = level > plainStars ? sentences(in: sharks) : []
        let wanted = level == 4 ? 3...4 : 4...6
        let allMine = sentences(in: [shark])
        let fitting = allMine.filter { wanted.contains($0.wordCount) }
        var mySentences = (fitting.count >= 2 ? fitting : allMine).shuffled(using: &generator)

        var rounds: [MissionChallenge] = []
        for index in 0..<max(1, shark.mission.targetCount) {
            let turn = index / 2
            var round: MissionChallenge?
            if !index.isMultiple(of: 2), level > plainStars {
                // The two hardest levels read whole sentences.
                while round == nil, let target = mySentences.popLast() {
                    let others = sentenceDistractors(for: target, in: sentencePool, using: &generator)
                    guard others.count == 2 else { continue }
                    round = build(.words, listenSentencePrompt, listenSentencePrompt, right: .phrase(target.text), others: others.map { .phrase($0.text) }, using: &generator)
                    round?.echo = target.echo
                }
            } else if !index.isMultiple(of: 2) {
                if level > 1, !turn.isMultiple(of: 2), let heart = hearts.popLast() {
                    round = word(heart, others: Array(heartPool.filter { $0 != heart }.shuffled(using: &generator).prefix(2)), using: &generator)
                } else if let target = targets.popLast() {
                    round = word(target, others: distractors(for: target, in: pool.decodable, level: level, using: &generator), using: &generator)
                }
            }
            var next = round ?? math(mathKinds[turn % mathKinds.count], level: level, using: &generator)
            // Never ask the very same thing twice in a row.
            for _ in 0..<4 where next.area == .math && next.spoken == rounds.last(where: { $0.area == .math })?.spoken {
                next = math(mathKinds[turn % mathKinds.count], level: level, using: &generator)
            }
            rounds.append(next)
        }
        return rounds
    }

    // MARK: Numbers

    private enum MathKind {
        case count, numeral, compare, oneMore, oneLess, teen, teenStep, plus, minus

        static func kinds(for level: Int) -> [MathKind] {
            switch level {
            case 1: [.count, .numeral, .count]
            case 2: [.count, .compare, .count]
            case 3: [.oneMore, .oneLess, .compare]
            case 4: [.plus, .teen, .teenStep]
            default: [.minus, .plus, .teenStep]
            }
        }
    }

    private static func math<Generator: RandomNumberGenerator>(_ kind: MathKind, level: Int, using generator: inout Generator) -> MissionChallenge {
        switch kind {
        case .count:
            let range = level == 1 ? 1...5 : 5...10
            let count = Int.random(in: range, using: &generator)
            // Neighbouring amounts, so the groups have to be counted rather than guessed by size.
            let others = neighbours(of: count, within: level == 1 ? 1...6 : 3...10, using: &generator)
            return build(.math, countLine(count), countLine(count), right: .group(count), others: others.map(Choice.group), using: &generator)
        case .numeral:
            let number = Int.random(in: 1...10, using: &generator)
            let others = Array((1...10).filter { $0 != number }.shuffled(using: &generator).prefix(2))
            return build(.math, numeralLine(number), numeralLine(number), right: .numeral(number), others: others.map(Choice.numeral), using: &generator)
        case .compare:
            let small = Int.random(in: 1...8, using: &generator)
            let big = level >= 3 ? small + 1 : Int.random(in: (small + 2)...10, using: &generator)
            let wantsMore = Bool.random(using: &generator)
            let line = wantsMore ? moreLine : fewerLine
            return build(.math, line, line, right: .group(wantsMore ? big : small), others: [.group(wantsMore ? small : big)], using: &generator)
        case .oneMore:
            let number = Int.random(in: 1...9, using: &generator)
            let others = Array([number - 1, number, number + 2].filter { (1...10).contains($0) }.shuffled(using: &generator).prefix(2))
            return build(.math, oneMoreLine(number), oneMoreLine(number), right: .numeral(number + 1), others: others.map(Choice.numeral), using: &generator)
        case .teen:
            let number = Int.random(in: 11...20, using: &generator)
            let others = Array((11...20).filter { $0 != number }.shuffled(using: &generator).prefix(2))
            return build(.math, numeralLine(number), numeralLine(number), right: .numeral(number), others: others.map(Choice.numeral), using: &generator)
        case .teenStep:
            let up = Bool.random(using: &generator)
            let number = up ? Int.random(in: 10...19, using: &generator) : Int.random(in: 11...20, using: &generator)
            let answer = up ? number + 1 : number - 1
            let others = Array([number, answer + (up ? 1 : -1), answer + (up ? -2 : 2)].filter { (8...22).contains($0) }.shuffled(using: &generator).prefix(2))
            let line = up ? oneMoreLine(number) : oneLessLine(number)
            return build(.math, line, line, right: .numeral(answer), others: others.map(Choice.numeral), using: &generator)
        case .plus:
            // Level four keeps sums small; level five goes all the way to ten.
            let first = Int.random(in: 1...(level == 4 ? 5 : 8), using: &generator)
            let second = Int.random(in: 1...min(level == 4 ? 4 : 9, 10 - first), using: &generator)
            let others = neighbours(of: first + second, within: 1...12, using: &generator)
            return build(.math, plusLine(first, second), "\(first) + \(second) = ?", right: .numeral(first + second), others: others.map(Choice.numeral), using: &generator)
        case .minus:
            let total = Int.random(in: 3...10, using: &generator)
            let taken = Int.random(in: 1...min(total - 1, 5), using: &generator)
            let others = neighbours(of: total - taken, within: 1...10, using: &generator)
            return build(.math, minusLine(total, taken), "\(total) − \(taken) = ?", right: .numeral(total - taken), others: others.map(Choice.numeral), using: &generator)
        case .oneLess:
            let number = Int.random(in: 2...10, using: &generator)
            let others = Array([number - 2, number, number + 1].filter { (1...10).contains($0) }.shuffled(using: &generator).prefix(2))
            return build(.math, oneLessLine(number), oneLessLine(number), right: .numeral(number - 1), others: others.map(Choice.numeral), using: &generator)
        }
    }

    private static func neighbours<Generator: RandomNumberGenerator>(of count: Int, within range: ClosedRange<Int>, using generator: inout Generator) -> [Int] {
        let near = [count - 2, count - 1, count + 1, count + 2].filter(range.contains).shuffled(using: &generator)
        return Array(near.prefix(2))
    }

    // MARK: Words

    private static func word<Generator: RandomNumberGenerator>(_ target: String, others: [String], using generator: inout Generator) -> MissionChallenge {
        build(.words, wordLine(target), listenPrompt, right: .word(target), others: others.map(Choice.word), using: &generator)
    }

    /// Other words of the same length. Level 1 picks words that look quite different (big, hot, sun);
    /// later levels pick near neighbours (big, bit, bug) so every letter has to be read.
    private static func distractors<Generator: RandomNumberGenerator>(for target: String, in pool: [String], level: Int, using generator: inout Generator) -> [String] {
        let shared: (String) -> Int = { word in zip(word, target).filter { $0 == $1 }.count }
        let same = pool.filter { $0 != target && $0.count == target.count }.shuffled(using: &generator)
        let far = same.sorted { shared($0) < shared($1) }
        let close = Array(far.reversed())
        switch level {
        case 1: return Array(far.prefix(2))
        case 2: return Array(Set(close.prefix(1) + far.prefix(1))).sorted()
        default: return Array(close.prefix(2))
        }
    }

    /// Other sentences with the same number of words, nearest first, so the words have to be read and not just counted.
    private static func sentenceDistractors<Generator: RandomNumberGenerator>(for target: Sentence, in pool: [Sentence], using generator: inout Generator) -> [Sentence] {
        let mine = target.words
        let shared: (Sentence) -> Int = { other in zip(other.words, mine).filter { $0 == $1 }.count }
        let same = pool.filter { $0.wordCount == target.wordCount && $0.words != mine }.shuffled(using: &generator)
        return Array(same.sorted { shared($0) > shared($1) }.prefix(2))
    }

    private static func build<Generator: RandomNumberGenerator>(
        _ area: MissionChallenge.Area,
        _ spoken: String,
        _ shown: String,
        right: MissionChallenge.Choice,
        others: [MissionChallenge.Choice],
        using generator: inout Generator
    ) -> MissionChallenge {
        var choices = others.filter { $0 != right }
        let answer = Int.random(in: 0...choices.count, using: &generator)
        choices.insert(right, at: answer)
        return MissionChallenge(area: area, spoken: spoken, shown: shown, choices: choices, answer: answer)
    }
}

private typealias Choice = MissionChallenge.Choice
