import XCTest
import LearningEngine
import LearningPersistence
import SwiftData
@testable import SharkExplorer

@MainActor
final class ContentStoreTests: XCTestCase {
    func testCatalogHasCompleteTenSharkScope() throws {
        let catalog = ContentStore.shared.catalog
        XCTAssertEqual(catalog.sharks.count, 10)
        XCTAssertEqual(catalog.sharks.flatMap(\.topics).count, 70)
        XCTAssertEqual(catalog.sharks.flatMap(\.questions).count, 50)
        XCTAssertEqual(catalog.vocabulary.count, 25)
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.count == 7 })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.allSatisfy { $0.id != "babies" } })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.questions.count == 5 })
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
        first.completeTopic(sharkID: shark.id, topicID: shark.topics[0].id)
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
        game.completeTopic(sharkID: shark.id, topicID: filterTrait.unlockTopicID)
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

}
