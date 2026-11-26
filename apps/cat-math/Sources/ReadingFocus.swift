import Foundation

/// A reading unit from school: a spelling pattern plus that week's sight words.
/// Story pages are written around one unit each, and its words are marked on the page.
struct ReadingFocus: Decodable, Identifiable, Equatable {
    enum WordKind { case pattern, sight }

    let id: String
    /// Child-facing name, e.g. "sh words".
    let title: String
    /// Monday of the school week that taught this unit (yyyy-MM-dd), so the newest can be featured.
    let week: String
    /// Letter groups that mark a pattern word anywhere in it, e.g. "sh".
    let contains: [String]
    /// Letter groups that mark a pattern word at its start, e.g. "st" for s blends.
    let prefixes: [String]
    /// Extra pattern words that no letter rule finds, such as plurals.
    let words: [String]
    /// Words that match a rule but should not be marked.
    let ignore: [String]
    let sightWords: [String]

    /// Whether `word` is one this unit practises. Sight words win over the pattern.
    func kind(of word: String) -> WordKind? {
        let word = Self.normalized(word)
        if sightWords.contains(word) { return .sight }
        if ignore.contains(word) { return nil }
        if words.contains(word) || contains.contains(where: word.contains) || prefixes.contains(where: { word.count > 2 && word.hasPrefix($0) }) {
            return .pattern
        }
        return nil
    }

    static func normalized(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: CharacterSet(charactersIn: "'‘"))
    }

    private struct File: Decodable { let units: [ReadingFocus] }

    /// Every unit in cat-reading.json; empty if the file is missing, which simply marks no words.
    static let all: [ReadingFocus] = {
        guard let url = Bundle.main.url(forResource: "cat-reading", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.units
    }()

    static func unit(_ id: String) -> ReadingFocus? { all.first { $0.id == id } }

    /// The unit taught most recently at school.
    static var newest: ReadingFocus? { all.max { $0.week < $1.week } }
}

extension CatStoryBeat {
    var focus: ReadingFocus? { ReadingFocus.unit(focusID) }
}

/// Asked after a story page, before its puzzles: one sentence from the page is read aloud and the child
/// finds it among three. Every sentence already has a recording, so the question needs no new ones.
struct ReadingQuestion: Equatable {
    /// The sentence that is read aloud.
    let sentence: String
    let choices: [String]

    /// Nil when a page is too short to offer three different sentences.
    static func question<Generator: RandomNumberGenerator>(for page: CatStoryBeat, using generator: inout Generator) -> ReadingQuestion? {
        var seen = Set<String>()
        let sentences = page.sentences.filter { seen.insert($0).inserted }.shuffled(using: &generator)
        guard sentences.count >= 3 else { return nil }
        return ReadingQuestion(sentence: sentences[0], choices: Array(sentences.prefix(3)).shuffled(using: &generator))
    }

    static func question(for page: CatStoryBeat) -> ReadingQuestion? {
        var generator = SystemRandomNumberGenerator()
        return question(for: page, using: &generator)
    }
}
