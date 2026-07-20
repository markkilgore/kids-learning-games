import Foundation
import SwiftUI
import LearningEngine
import LearningUI

struct GameCatalog: Codable {
    let schemaVersion: Int
    let sharks: [SharkDefinition]
    let vocabulary: [VocabularyDefinition]
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
    let mission: MissionDefinition
    let questions: [QuestionDefinition]
    let vocabularyIDs: [String]
    let bookFact: String
    let sourceURLs: [String]

    var tint: Color { Color(hex: color) }
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
