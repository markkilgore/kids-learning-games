import XCTest
import LearningEngine
import LearningPersistence
import SwiftData
import Narration
@testable import LearningUI
@testable import SharkExplorer

@MainActor
final class ContentStoreTests: XCTestCase {
    func testCatalogHasCompleteTenSharkScope() throws {
        let catalog = ContentStore.shared.catalog
        XCTAssertEqual(catalog.sharks.count, 10)
        XCTAssertEqual(catalog.sharks.flatMap(\.topics).count, 70)
        XCTAssertEqual(catalog.sharks.flatMap(\.questions).count, 30)
        XCTAssertEqual(catalog.vocabulary.count, 25)
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.count == 7 })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.allSatisfy { $0.id != "babies" } })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.questions.count == 3 })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.traits.count >= 2 })
        XCTAssertTrue(catalog.sharks.allSatisfy { shark in
            shark.traits.allSatisfy { shark.topics.map(\.id).contains($0.unlockTopicID) }
        })
    }

    func testBothReadingModesHaveContent() throws {
        let catalog = ContentStore.shared.catalog
        for shark in catalog.sharks {
            XCTAssertFalse(shark.discover.earlyReader.isEmpty, shark.id)
            XCTAssertFalse(shark.discover.story.isEmpty, shark.id)
            for topic in shark.topics {
                XCTAssertFalse(topic.narration.earlyReader.isEmpty, "\(shark.id)/\(topic.id)")
                XCTAssertFalse(topic.narration.story.isEmpty, "\(shark.id)/\(topic.id)")
            }
        }
    }

    func testQuestionsHaveExactlyOneCorrectChoice() throws {
        for question in ContentStore.shared.catalog.sharks.flatMap(\.questions) {
            XCTAssertEqual(question.choices.count, 3)
            XCTAssertEqual(question.choices.filter { $0.id == question.correctID }.count, 1)
        }
    }

    func testQuizChoiceOrderingPreservesChoicesAndBalancesCorrectPositions() {
        for (sharkIndex, shark) in ContentStore.shared.catalog.sharks.enumerated() {
            var generator = SeededRandomNumberGenerator(seed: UInt64(sharkIndex + 1))
            let orderedChoices = QuizChoiceOrderer.order(for: shark.questions, using: &generator)

            XCTAssertEqual(orderedChoices.count, shark.questions.count)

            let correctPositions = zip(shark.questions, orderedChoices).compactMap { question, choices in
                XCTAssertEqual(Set(choices), Set(question.choices), question.id)
                return choices.firstIndex { $0.id == question.correctID }
            }
            let positionCounts = Dictionary(grouping: correctPositions, by: { $0 }).values.map(\.count)

            XCTAssertEqual(correctPositions.count, shark.questions.count)
            XCTAssertEqual(Set(correctPositions), Set(shark.questions[0].choices.indices), shark.id)
            XCTAssertLessThanOrEqual((positionCounts.max() ?? 0) - (positionCounts.min() ?? 0), 1, shark.id)
        }
    }

    func testGuidedUnlockThresholds() throws {
        let game = GameStore()
        let sharks = ContentStore.shared.catalog.sharks
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 3)
        game.completedSharks = ["whale"]
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 5)
        game.completedSharks = ["whale", "hammerhead", "nurse"]
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 8)
        game.completedSharks = ["whale", "hammerhead", "nurse", "great-white", "wobbegong", "thresher"]
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 10)
    }

    func testMissionCompletionPersistsRewardsAndRestoresDestination() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.shark", baseDirectory: base)
        let shark = ContentStore.shared.catalog.sharks[0]
        let first = GameStore(progressStore: storage)
        first.load()
        first.open(shark)
        first.completeTopic(shark.topics[0], for: shark)
        first.completeMission(for: shark)

        let restored = GameStore(progressStore: storage)
        restored.load()
        XCTAssertEqual(restored.destination, .encounter(shark.id))
        XCTAssertTrue(restored.completedSharks.contains(shark.id))
        XCTAssertTrue(restored.collectedWords.isSuperset(of: shark.vocabularyIDs))
        XCTAssertTrue(restored.completedTopics.contains("\(shark.id):\(shark.topics[0].id)"))
    }

    func testPassportTraitsUnlockFromExploreProgressOrMissionCompletion() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.passport", baseDirectory: base)
        let game = GameStore(progressStore: storage)
        let shark = ContentStore.shared.catalog.sharks.first { $0.id == "whale" }!
        let filterTrait = shark.traits.first { $0.id == "filter-mouth" }!

        XCTAssertFalse(game.hasUnlocked(filterTrait, for: shark))
        game.completeTopic(shark.topics.first { $0.id == filterTrait.unlockTopicID }!, for: shark)
        XCTAssertTrue(game.hasUnlocked(filterTrait, for: shark))

        let otherTrait = shark.traits.first { $0.id != filterTrait.id }!
        XCTAssertFalse(game.hasUnlocked(otherTrait, for: shark))
        game.completeMission(for: shark)
        XCTAssertTrue(game.hasUnlocked(otherTrait, for: shark))
    }

    func testConfigurationMatchesSharkReleaseIdentity() {
        let config = SharkAppConfiguration.value
        XCTAssertEqual(config.identity.applicationIdentifier, "com.mkilgore.SharkExplorer")
        XCTAssertEqual(config.identity.childFacingName, "Henry’s Shark Explorer")
        XCTAssertEqual(config.storageNamespace, "com.mkilgore.SharkExplorer.henry")
        XCTAssertFalse(config.enabledSkills.contains { $0.id.contains("math") })
    }

    func testLegacySwiftDataProgressMapsWithoutLoss() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlayerProgressRecord.self, configurations: configuration)
        let record = PlayerProgressRecord(
            completedSharksCSV: "whale,nurse",
            collectedWordsCSV: "plankton,filter",
            completedTopicsCSV: "whale:size,nurse:home",
            currentSharkID: "nurse",
            readingModeRaw: ReadingMode.story.rawValue
        )
        container.mainContext.insert(record)
        try container.mainContext.save()

        let progress = LegacySharkProgressMigration.load(container: container)
        XCTAssertEqual(progress?.completedSharks, ["whale", "nurse"])
        XCTAssertEqual(progress?.collectedWords, ["plankton", "filter"])
        XCTAssertEqual(progress?.currentSharkID, "nurse")
        XCTAssertEqual(progress?.readingMode, .story)
    }

    func testMissionRewardReportsNewPageWordsAndUnlockedSharks() throws {
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.reward", baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let game = GameStore(progressStore: storage)
        let sharks = ContentStore.shared.catalog.sharks
        let first = try XCTUnwrap(sharks.first { $0.unlockAt == 0 })
        let waiting = sharks.filter { $0.unlockAt == 1 }
        XCTAssertEqual(game.missionsNeeded(for: waiting[0]), 1)

        let reward = game.completeMission(for: first)
        XCTAssertTrue(reward.isNewPage)
        XCTAssertEqual(reward.newWordIDs, first.vocabularyIDs)
        XCTAssertEqual(Set(reward.unlockedSharkIDs), Set(waiting.map(\.id)))
        XCTAssertEqual(game.freshlyUnlockedSharkIDs, Set(waiting.map(\.id)))

        let again = game.completeMission(for: first)
        XCTAssertFalse(again.isNewPage)
        XCTAssertTrue(again.newWordIDs.isEmpty)
        XCTAssertTrue(again.unlockedSharkIDs.isEmpty)
    }

    func testTopicCompletionReturnsNewTraitOnlyOnce() throws {
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.trait", baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let game = GameStore(progressStore: storage)
        let shark = ContentStore.shared.catalog.sharks[0]
        let trait = shark.traits[0]
        let topic = try XCTUnwrap(shark.topics.first { $0.id == trait.unlockTopicID })
        XCTAssertEqual(game.completeTopic(topic, for: shark).map(\.id), shark.traits.filter { $0.unlockTopicID == topic.id }.map(\.id))
        XCTAssertTrue(game.completeTopic(topic, for: shark).isEmpty)
    }

    func testProgressSavedBeforeQuizCountsStillDecodes() throws {
        let oldSave = Data(#"{"collectedWords":["teeth"],"completedSharks":["whale"],"completedTopics":["whale:food"],"currentSharkID":"whale","readingMode":"story"}"#.utf8)
        let decoded = try JSONDecoder().decode(SharkProgress.self, from: oldSave)
        XCTAssertEqual(decoded.completedSharks, ["whale"])
        XCTAssertEqual(decoded.collectedWords, ["teeth"])
        XCTAssertEqual(decoded.completedTopics, ["whale:food"])
        XCTAssertEqual(decoded.currentSharkID, "whale")
        XCTAssertEqual(decoded.readingMode, .story)
        XCTAssertTrue(decoded.quizFirstTry.isEmpty)
        XCTAssertTrue(decoded.quizRetried.isEmpty)

        // An old file on disk loads into the store with no quiz answers recorded.
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.oldsave", baseDirectory: base)
        let url = try storage.fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try oldSave.write(to: url)
        let game = GameStore(progressStore: storage)
        game.load()
        XCTAssertTrue(game.completedSharks.contains("whale"))
        XCTAssertEqual(game.quizTally().firstTry, 0)
        XCTAssertEqual(game.quizTally().retried, 0)
    }

    func testQuizAnswersAreCountedPerSharkAndPersist() throws {
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.quiz", baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let sharks = ContentStore.shared.catalog.sharks
        let game = GameStore(progressStore: storage)
        game.load()
        game.recordQuizQuestion(for: sharks[0], firstTry: true)
        game.recordQuizQuestion(for: sharks[0], firstTry: false)
        game.recordQuizQuestion(for: sharks[0], firstTry: true)
        game.recordQuizQuestion(for: sharks[1], firstTry: false)

        let restored = GameStore(progressStore: storage)
        restored.load()
        XCTAssertEqual(restored.quizTally(for: sharks[0]).firstTry, 2)
        XCTAssertEqual(restored.quizTally(for: sharks[0]).retried, 1)
        XCTAssertEqual(restored.quizTally(for: sharks[1]).retried, 1)
        XCTAssertEqual(restored.quizTally().firstTry, 2)
        XCTAssertEqual(restored.quizTally().retried, 2)
        XCTAssertEqual(SharkProgressSection.accuracy(firstTry: 2, retried: 1), "67% (2 of 3)")
        XCTAssertEqual(SharkProgressSection.accuracy(firstTry: 0, retried: 0), "—")
        XCTAssertNotNil(SharkProgressSection.note(for: sharks[1], firstTry: 1, retried: 2))
        XCTAssertNil(SharkProgressSection.note(for: sharks[0], firstTry: 2, retried: 1))
    }

    /// Every line the app can speak must have a bundled recording, or it falls back to the robotic device voice.
    func testEverySpokenLineHasARecording() throws {
        let manifest = AudioManifest(bundle: .main, resourceName: SharkAppConfiguration.value.narration.bundledManifestName)
        let catalog = ContentStore.shared.catalog
        var lines = WeeklySpokenLines.all + SharkLine.allCases.map(\.text) + catalog.vocabulary.map(\.word)
        for shark in catalog.sharks {
            let narratives = [shark.discover, shark.mission.instructions] + shark.topics.map(\.narration) + shark.questions.map(\.prompt)
            lines += narratives.flatMap { $0.earlyReader + $0.story }
            lines.append(shark.mission.completion)
            lines += shark.questions.flatMap { [$0.success, $0.retry] }
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "shark-weeks", withExtension: "json"))
        for week in try JSONDecoder().decode([LessonWeek].self, from: Data(contentsOf: url)) {
            lines.append(week.overview)
            lines += week.activities.flatMap(\.steps).flatMap { [$0.spoken ?? $0.prompt, $0.hint] }
        }
        XCTAssertFalse(lines.contains(""), "a SharkLine key is missing from ui-lines.json")
        let missing = Set(lines).filter { manifest.clipURL(for: $0) == nil }
        XCTAssertEqual(missing.sorted(), [], "run `npm --prefix tools run audio`")
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}
