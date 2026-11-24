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
    /// Quiz questions answered right on the first tap, keyed by shark ID.
    var quizFirstTry: [String: Int] = [:]
    /// Quiz questions that needed another try, keyed by shark ID.
    var quizRetried: [String: Int] = [:]
}

// Decoding lives in an extension so the memberwise initializer stays available.
extension SharkProgress {
    /// Every field falls back to its default, so saves from before a field existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            completedSharks: try container.decodeIfPresent(Set<String>.self, forKey: .completedSharks) ?? [],
            collectedWords: try container.decodeIfPresent(Set<String>.self, forKey: .collectedWords) ?? [],
            completedTopics: try container.decodeIfPresent(Set<String>.self, forKey: .completedTopics) ?? [],
            currentSharkID: try container.decodeIfPresent(String.self, forKey: .currentSharkID),
            readingMode: try container.decodeIfPresent(ReadingMode.self, forKey: .readingMode) ?? .earlyReader,
            quizFirstTry: try container.decodeIfPresent([String: Int].self, forKey: .quizFirstTry) ?? [:],
            quizRetried: try container.decodeIfPresent([String: Int].self, forKey: .quizRetried) ?? [:]
        )
    }
}

enum AppDestination: Hashable {
    case map
    case encounter(String)
    case books
    case settings
}

/// What finishing a shark's mission and questions earned.
struct MissionReward: Equatable {
    let isNewPage: Bool
    let newWordIDs: [String]
    let unlockedSharkIDs: [String]
}

@MainActor
@Observable
final class GameStore {
    var destination: AppDestination = .map
    var readingMode: ReadingMode = .earlyReader
    var completedSharks: Set<String> = []
    var collectedWords: Set<String> = []
    var completedTopics: Set<String> = []
    private(set) var quizFirstTry: [String: Int] = [:]
    private(set) var quizRetried: [String: Int] = [:]
    /// The Passport page to show when the books open next.
    var passportSharkID: String?
    /// Sharks unlocked by the latest mission, so the map can reveal them.
    var freshlyUnlockedSharkIDs: Set<String> = []
    private let progressStore: NamespacedProgressStore<SharkProgress>?
    private var didLoad = false

    init(progressStore: NamespacedProgressStore<SharkProgress>? = nil) {
        self.progressStore = progressStore ?? (try? NamespacedProgressStore(namespace: SharkAppConfiguration.value.storageNamespace))
    }

    var completedCount: Int { completedSharks.count }

    func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let progressStore else { return }
        if !progressStore.exists, let legacy = LegacySharkProgressMigration.load() {
            try? progressStore.save(legacy)
        }
        let progress = (try? progressStore.load(default: SharkProgress())) ?? SharkProgress()
        completedSharks = progress.completedSharks
        collectedWords = progress.collectedWords
        completedTopics = progress.completedTopics
        readingMode = progress.readingMode
        quizFirstTry = progress.quizFirstTry
        quizRetried = progress.quizRetried
        if let current = progress.currentSharkID { destination = .encounter(current) }
    }

    func isUnlocked(_ shark: SharkDefinition) -> Bool {
        completedSharks.contains(shark.id) || completedCount >= shark.unlockAt
    }

    /// How many more missions reveal a locked shark.
    func missionsNeeded(for shark: SharkDefinition) -> Int { max(0, shark.unlockAt - completedCount) }

    func open(_ shark: SharkDefinition) {
        guard isUnlocked(shark) else { return }
        freshlyUnlockedSharkIDs.remove(shark.id)
        destination = .encounter(shark.id)
        save(currentSharkID: shark.id)
    }

    func showMap() {
        destination = .map
        save(currentSharkID: nil)
    }

    func showBooks(openingPageFor sharkID: String? = nil) {
        if let sharkID { passportSharkID = sharkID }
        destination = .books
        save(currentSharkID: nil)
    }

    func setReadingMode(_ mode: ReadingMode) {
        readingMode = mode
        save()
    }

    /// Records a finished topic and returns the trait cards it revealed for the first time.
    @discardableResult
    func completeTopic(_ topic: ExploreTopic, for shark: SharkDefinition) -> [TraitDefinition] {
        let revealed = shark.traits.filter { $0.unlockTopicID == topic.id && !hasUnlocked($0, for: shark) }
        completedTopics.insert("\(shark.id):\(topic.id)")
        save()
        return revealed
    }

    func hasCompleted(_ topic: ExploreTopic, for shark: SharkDefinition) -> Bool {
        completedTopics.contains("\(shark.id):\(topic.id)")
    }

    func hasUnlocked(_ trait: TraitDefinition, for shark: SharkDefinition) -> Bool {
        completedSharks.contains(shark.id) || completedTopics.contains("\(shark.id):\(trait.unlockTopicID)")
    }

    /// Records a quiz question once it is answered correctly; `firstTry` is false if a wrong choice came first.
    func recordQuizQuestion(for shark: SharkDefinition, firstTry: Bool) {
        if firstTry {
            quizFirstTry[shark.id, default: 0] += 1
        } else {
            quizRetried[shark.id, default: 0] += 1
        }
        save()
    }

    /// Quiz questions answered for one shark, or for every shark when `shark` is nil.
    func quizTally(for shark: SharkDefinition? = nil) -> (firstTry: Int, retried: Int) {
        guard let shark else { return (quizFirstTry.values.reduce(0, +), quizRetried.values.reduce(0, +)) }
        return (quizFirstTry[shark.id, default: 0], quizRetried[shark.id, default: 0])
    }

    @discardableResult
    func completeMission(for shark: SharkDefinition, in sharks: [SharkDefinition] = ContentStore.shared.catalog.sharks) -> MissionReward {
        let lockedBefore = sharks.filter { !isUnlocked($0) }
        let reward = MissionReward(
            isNewPage: !completedSharks.contains(shark.id),
            newWordIDs: shark.vocabularyIDs.filter { !collectedWords.contains($0) },
            unlockedSharkIDs: []
        )
        completedSharks.insert(shark.id)
        collectedWords.formUnion(shark.vocabularyIDs)
        let unlocked = lockedBefore.filter(isUnlocked).map(\.id)
        freshlyUnlockedSharkIDs.formUnion(unlocked)
        save()
        return MissionReward(isNewPage: reward.isNewPage, newWordIDs: reward.newWordIDs, unlockedSharkIDs: unlocked)
    }

    private func save(currentSharkID: String? = nil) {
        let persistedCurrentID: String?
        switch destination {
        case .encounter(let id): persistedCurrentID = currentSharkID ?? id
        default: persistedCurrentID = nil
        }
        try? progressStore?.save(SharkProgress(
            completedSharks: completedSharks,
            collectedWords: collectedWords,
            completedTopics: completedTopics,
            currentSharkID: persistedCurrentID,
            readingMode: readingMode,
            quizFirstTry: quizFirstTry,
            quizRetried: quizRetried
        ))
    }
}
