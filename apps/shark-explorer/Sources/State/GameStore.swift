import Foundation
import LearningEngine
import LearningPersistence
import Observation

struct SharkProgress: Codable, Equatable {
    var completedSharks: Set<String> = []
    var collectedWords: Set<String> = []
    var completedTopics: Set<String> = []
    var currentSharkID: String?
    var readingMode: ReadingMode = .earlyReader
}

enum AppDestination: Hashable {
    case map
    case encounter(String)
    case books
    case settings
}

@MainActor
@Observable
final class GameStore {
    var destination: AppDestination = .map
    var readingMode: ReadingMode = .earlyReader
    var completedSharks: Set<String> = []
    var collectedWords: Set<String> = []
    var completedTopics: Set<String> = []
    private let progressStore: NamespacedProgressStore<SharkProgress>
    private var didLoad = false

    init(progressStore: NamespacedProgressStore<SharkProgress>? = nil) {
        self.progressStore = progressStore ?? (try! NamespacedProgressStore(namespace: SharkAppConfiguration.value.storageNamespace))
    }

    var completedCount: Int { completedSharks.count }

    func load() {
        guard !didLoad else { return }
        didLoad = true
        if !progressStore.exists, let legacy = LegacySharkProgressMigration.load() {
            try? progressStore.save(legacy)
        }
        let progress = (try? progressStore.load(default: SharkProgress())) ?? SharkProgress()
        completedSharks = progress.completedSharks
        collectedWords = progress.collectedWords
        completedTopics = progress.completedTopics
        readingMode = progress.readingMode
        if let current = progress.currentSharkID { destination = .encounter(current) }
    }

    func isUnlocked(_ shark: SharkDefinition) -> Bool {
        completedSharks.contains(shark.id) || completedCount >= shark.unlockAt
    }

    func open(_ shark: SharkDefinition) {
        guard isUnlocked(shark) else { return }
        destination = .encounter(shark.id)
        save(currentSharkID: shark.id)
    }

    func showMap() {
        destination = .map
        save(currentSharkID: nil)
    }

    func setReadingMode(_ mode: ReadingMode) {
        readingMode = mode
        save()
    }

    func completeTopic(sharkID: String, topicID: String) {
        completedTopics.insert("\(sharkID):\(topicID)")
        save()
    }

    func hasUnlocked(_ trait: TraitDefinition, for shark: SharkDefinition) -> Bool {
        completedSharks.contains(shark.id) || completedTopics.contains("\(shark.id):\(trait.unlockTopicID)")
    }

    func completeMission(for shark: SharkDefinition) {
        completedSharks.insert(shark.id)
        collectedWords.formUnion(shark.vocabularyIDs)
        save()
    }

    private func save(currentSharkID: String? = nil) {
        let persistedCurrentID: String?
        switch destination {
        case .encounter(let id): persistedCurrentID = currentSharkID ?? id
        default: persistedCurrentID = nil
        }
        try? progressStore.save(SharkProgress(
            completedSharks: completedSharks,
            collectedWords: collectedWords,
            completedTopics: completedTopics,
            currentSharkID: persistedCurrentID,
            readingMode: readingMode
        ))
    }
}
