import Foundation
import SwiftUI
import LearningEngine
import LearningUI

struct GameCatalog: Codable {
    let schemaVersion: Int
    let sharks: [SharkDefinition]
    let vocabulary: [VocabularyDefinition]
    let expansions: [SharkExpansion]?
}

struct SharkExpansion: Codable, Hashable {
    let sharkID: String
    let topics: [ExploreTopic]
    let questions: [QuestionDefinition]
    let sourceURLs: [String]
}

struct SharkDefinition: Codable, Identifiable, Hashable {
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
    let discover: NarrativePair
    let topics: [ExploreTopic]
    let traits: [TraitDefinition]
    let mission: MissionDefinition
    let questions: [QuestionDefinition]
    let vocabularyIDs: [String]
    let bookFact: String
    let sourceURLs: [String]

    var tint: Color { Color(hex: color) }

    func expanded(with expansion: SharkExpansion?) -> SharkDefinition {
        guard let expansion else { return self }
        return SharkDefinition(
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
        "shellCrunch": MissionPlay(targetAsset: "mission-urchin", targetSymbol: "🟣")
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
