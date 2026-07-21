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
    let earlyReader: [String]
    let story: [String]

    func sentences(for mode: ReadingMode) -> [String] {
        mode == .earlyReader ? earlyReader : story
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

struct VocabularyDefinition: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let symbol: String
    let explanation: String
}
