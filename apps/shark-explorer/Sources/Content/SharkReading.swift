import Foundation
import LearningUI

/// What Henry can read so far, from shark-reading.json: the letters taught in class and the heart words.
/// A word counts as "sound it out" when it is a short-vowel word (at, big, fins) made only of those letters.
struct SharkReading: Decodable, Sendable {
    let letters: [String]
    let newestLetters: [String]
    let heartWords: [String]
    /// Short words that look decodable but are not said the way they are spelled.
    let irregular: [String]

    static let shared: SharkReading = {
        guard let url = Bundle.main.url(forResource: "shark-reading", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let reading = try? JSONDecoder().decode(SharkReading.self, from: data) else {
            return SharkReading(letters: [], newestLetters: [], heartWords: [], irregular: [])
        }
        return reading
    }()

    func mark(_ word: String) -> WordMark? {
        let word = word.lowercased()
        if heartWords.contains(word) { return .heart }
        guard !irregular.contains(word), !word.isEmpty, word.allSatisfy({ letters.contains(String($0)) }) else { return nil }
        // "fins" is "fin" plus the -s ending, which has been taught.
        let bases = word.count > 3 && word.hasSuffix("s") ? [word, String(word.dropLast())] : [word]
        guard bases.contains(where: Self.isShortVowelWord) else { return nil }
        return newestLetters.contains(where: word.contains) ? .featured : .decodable
    }

    /// Vowel-consonant or consonant-vowel-consonant, with no r after the vowel (car, her are not short vowels).
    private static func isShortVowelWord(_ word: String) -> Bool {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        let letters = Array(word)
        guard letters.count == 2 || letters.count == 3 else { return false }
        let ending = letters[letters.count - 1], vowel = letters[letters.count - 2]
        guard vowels.contains(vowel), !vowels.contains(ending), ending != "r" else { return false }
        return letters.count == 2 || !vowels.contains(letters[0])
    }
}
