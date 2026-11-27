import Foundation
import SwiftUI
import LearningEngine
import LearningUI

struct GameCatalog: Codable {
    /// The catalog file still calls the animals "sharks"; that key stays so older tools keep reading it.
    enum CodingKeys: String, CodingKey {
        case schemaVersion, vocabulary, expansions, maps
        case animals = "sharks"
    }

    let schemaVersion: Int
    /// Every animal on the map. All are sharks today; `AnimalDefinition.kind` says otherwise when that changes.
    let animals: [AnimalDefinition]
    let vocabulary: [VocabularyDefinition]
    let expansions: [AnimalExpansion]?
    /// The pages of the map, swiped between. Oceans today; other worlds (prehistoric seas, dinosaurs) can be added as pages.
    var maps: [MapPage]?

    var mapPages: [MapPage] { maps ?? [MapPage(id: "ocean", name: "Ocean", symbol: "map.fill")] }

    /// What to call the animals in general: "shark" while they all are, "animal" once kinds are mixed.
    var commonKind: AnimalKind {
        let kinds = Set(animals.map(\.kindInfo))
        return kinds.count == 1 ? kinds.first ?? .shark : .mixed
    }

    func animals(on page: MapPage) -> [AnimalDefinition] {
        animals.filter { ($0.map ?? mapPages[0].id) == page.id }
    }
}

/// The words used for a kind of animal in child-facing text. Add an entry here (and its recordings; see the
/// content guide) before putting a new kind in the catalog.
struct AnimalKind: Hashable {
    let id: String
    let noun: String
    let plural: String

    /// "a shark", "an animal".
    var withArticle: String { ("aeiou".contains(noun.prefix(1)) ? "an " : "a ") + noun }

    static let shark = AnimalKind(id: "shark", noun: "shark", plural: "sharks")
    static let mixed = AnimalKind(id: "animal", noun: "animal", plural: "animals")
    static let fish = AnimalKind(id: "fish", noun: "fish", plural: "fish")
    static let seaReptile = AnimalKind(id: "sea-reptile", noun: "sea reptile", plural: "sea reptiles")
    static let whale = AnimalKind(id: "whale", noun: "whale", plural: "whales")
    static let all = [shark, fish, seaReptile, whale]
}

struct MapPage: Codable, Identifiable, Hashable {
    let id: String
    /// Short enough for a tab, e.g. "Pacific".
    let name: String
    let symbol: String
}

struct AnimalExpansion: Codable, Hashable {
    let sharkID: String
    let topics: [ExploreTopic]
    let questions: [QuestionDefinition]
    let sourceURLs: [String]
}

struct AnimalDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let scientificName: String
    let symbol: String
    let imageAsset: String
    let imageAuthor: String
    let imageLicense: String
    let imageSourceURL: String
    let color: String
    let region: String
    let mapX: Double
    let mapY: Double
    let unlockAt: Int
    /// Stars needed across all sharks before this one appears, on top of `unlockAt`. Earning them means replaying earlier sharks at harder levels.
    var unlockStars: Int?
    /// Super stars (a shark's fourth and fifth) needed across all sharks before this one appears.
    var unlockSuperStars: Int?
    /// The map page this animal is on; `mapX` and `mapY` are positions on that page.
    var map: String?
    /// What kind of animal this is, an `AnimalKind` id. Left out of the catalog for sharks.
    var kind: String?

    var kindInfo: AnimalKind { AnimalKind.all.first { $0.id == kind } ?? .shark }
    let discover: NarrativePair
    let topics: [ExploreTopic]
    let traits: [TraitDefinition]
    let mission: MissionDefinition
    let questions: [QuestionDefinition]
    let vocabularyIDs: [String]
    let bookFact: String
    let sourceURLs: [String]

    var tint: Color { Color(hex: color) }

    func expanded(with expansion: AnimalExpansion?) -> AnimalDefinition {
        guard let expansion else { return self }
        return AnimalDefinition(
            id: id,
            name: name,
            scientificName: scientificName,
            symbol: symbol,
            imageAsset: imageAsset,
            imageAuthor: imageAuthor,
            imageLicense: imageLicense,
            imageSourceURL: imageSourceURL,
            color: color,
            region: region,
            mapX: mapX,
            mapY: mapY,
            unlockAt: unlockAt,
            unlockStars: unlockStars,
            unlockSuperStars: unlockSuperStars,
            map: map,
            kind: kind,
            discover: discover,
            topics: topics + expansion.topics,
            traits: traits,
            mission: mission,
            questions: questions + expansion.questions,
            vocabularyIDs: vocabularyIDs,
            bookFact: bookFact,
            sourceURLs: sourceURLs + expansion.sourceURLs
        )
    }
}

struct NarrativePair: Codable, Hashable {
    /// Sentences a beginning reader can sound out alone, shown before the early-reader text.
    var decodable: [String]?
    let earlyReader: [String]
    let story: [String]

    func sentences(for mode: ReadingMode) -> [String] {
        mode == .earlyReader ? (decodable ?? []) + earlyReader : story
    }
}

struct ExploreTopic: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let narration: NarrativePair
}

struct TraitDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let description: String
    let imageAsset: String?
    let unlockTopicID: String
}

struct MissionDefinition: Codable, Hashable {
    let kind: String
    let title: String
    let symbol: String
    let instructions: NarrativePair
    let targetCount: Int
    let completion: String
}

/// What a mission kind shows while it is played. Every kind in the catalog needs an entry here.
struct MissionPlay: Equatable {
    /// Bundled cut-out drawn for the target; nil when the scene draws its own shape.
    let targetAsset: String?
    /// Stands in for the cut-out if the image is missing.
    let targetSymbol: String

    static let fallback = MissionPlay(targetAsset: "mission-star", targetSymbol: "⭐️")

    static let byKind: [String: MissionPlay] = [
        "ambushApproach": MissionPlay(targetAsset: nil, targetSymbol: "⭐️"),
        "filterFeed": MissionPlay(targetAsset: "mission-plankton", targetSymbol: "✨"),
        "electrosense": MissionPlay(targetAsset: "mission-electric", targetSymbol: "⚡️"),
        "suctionForage": MissionPlay(targetAsset: "mission-crab", targetSymbol: "🦀"),
        "camouflageFind": MissionPlay(targetAsset: "mission-shell", targetSymbol: "🐚"),
        "tailStrike": MissionPlay(targetAsset: "mission-fish", targetSymbol: "🐟"),
        "scentTrack": MissionPlay(targetAsset: "mission-scent", targetSymbol: "〰️"),
        "tidalWalk": MissionPlay(targetAsset: "mission-rock", targetSymbol: "🪨"),
        "jawStrike": MissionPlay(targetAsset: "mission-deep-fish", targetSymbol: "🐠"),
        "energyTrail": MissionPlay(targetAsset: "mission-snowflake", targetSymbol: "❄️"),
        "speedChase": MissionPlay(targetAsset: "mission-tuna", targetSymbol: "🐟"),
        "snailHunt": MissionPlay(targetAsset: "mission-snail", targetSymbol: "🐌"),
        "reefPatrol": MissionPlay(targetAsset: "mission-reef-fish", targetSymbol: "🐠"),
        "mangroveNursery": MissionPlay(targetAsset: "mission-mangrove", targetSymbol: "🌿"),
        "riverJourney": MissionPlay(targetAsset: "mission-wave", targetSymbol: "🌊"),
        "sawSweep": MissionPlay(targetAsset: "mission-shrimp", targetSymbol: "🦐"),
        "glowLure": MissionPlay(targetAsset: "mission-glow", targetSymbol: "🟢"),
        "sandAmbush": MissionPlay(targetAsset: "mission-flatfish", targetSymbol: "🐟"),
        "squidHunt": MissionPlay(targetAsset: "mission-squid", targetSymbol: "🦑"),
        "shellCrunch": MissionPlay(targetAsset: "mission-urchin", targetSymbol: "🟣"),
        "ammoniteHunt": MissionPlay(targetAsset: "mission-ammonite", targetSymbol: "🐚")
    ]
}

extension MissionDefinition {
    var play: MissionPlay { MissionPlay.byKind[kind] ?? .fallback }
}

struct QuestionDefinition: Codable, Identifiable, Hashable {
    let id: String
    let prompt: NarrativePair
    let choices: [AnswerChoice]
    let correctID: String
    let success: String
    let retry: String
}

struct AnswerChoice: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String
}

enum QuizChoiceOrderer {
    static func order(for questions: [QuestionDefinition]) -> [[AnswerChoice]] {
        var generator = SystemRandomNumberGenerator()
        return order(for: questions, using: &generator)
    }

    static func order<Generator: RandomNumberGenerator>(
        for questions: [QuestionDefinition],
        using generator: inout Generator
    ) -> [[AnswerChoice]] {
        var correctPositions: [Int: Int] = [:]

        for (choiceCount, questionIndices) in Dictionary(grouping: questions.indices, by: { questions[$0].choices.count }) {
            guard choiceCount > 0 else { continue }
            let startingPosition = Int.random(in: 0..<choiceCount, using: &generator)
            var positions = questionIndices.indices.map { (startingPosition + $0) % choiceCount }
            positions.shuffle(using: &generator)

            for (offset, questionIndex) in questionIndices.enumerated() {
                correctPositions[questionIndex] = positions[offset]
            }
        }

        return questions.enumerated().map { questionIndex, question in
            guard
                let correctChoice = question.choices.first(where: { $0.id == question.correctID }),
                let correctPosition = correctPositions[questionIndex]
            else {
                return question.choices.shuffled(using: &generator)
            }

            var orderedChoices = question.choices.filter { $0.id != question.correctID }
            orderedChoices.shuffle(using: &generator)
            orderedChoices.insert(correctChoice, at: correctPosition)
            return orderedChoices
        }
    }
}

struct VocabularyDefinition: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let symbol: String
    let explanation: String
}
