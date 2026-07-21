import XCTest
@testable import CatMathAdventure

@MainActor
final class CatMathTests: XCTestCase {
    func testCatScopeHasTwoLocationsTenCatsAndRequiredSkills() {
        XCTAssertEqual(Set(CatContent.locations.map(\.id)), ["house", "garden"])
        XCTAssertEqual(CatContent.cats.count, 10)
        XCTAssertEqual(Set(CatAppConfiguration.value.enabledSkills.map(\.id)), ["counting", "addition", "subtraction", "odd-even", "skip-5", "skip-10"])
    }

    func testFriendshipUnlocksAndPersistsWithoutSharkVocabulary() {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = CatGameStore(baseDirectory: base)
        first.load()
        let mittens = CatContent.cats.first { $0.id == "mittens" }!
        XCTAssertTrue(first.isUnlocked(mittens))
        first.completeActivity(for: mittens)

        let restored = CatGameStore(baseDirectory: base)
        restored.load()
        XCTAssertEqual(restored.friendship(for: mittens), 1)
        XCTAssertTrue(restored.progress.journaledCatIDs.contains(mittens.id))
        XCTAssertFalse(CatAppConfiguration.value.rewards.plural.lowercased().contains("shark"))
    }

    func testEveryChallengeHasCorrectChoiceAndVisualHint() {
        for cat in CatContent.cats {
            for friendship in 0..<12 {
                let challenge = MathChallengeFactory.challenge(for: cat, friendship: friendship)
                XCTAssertTrue(challenge.choices.contains(challenge.answer), "\(cat.id)/\(challenge.skill.id)")
                XCTAssertFalse(challenge.visualHint.isEmpty)
            }
        }
    }

    func testChallengeVisualsMatchTheirMathProblem() {
        let mittens = CatContent.cats.first { $0.id == "mittens" }!
        let challenges = (0..<12).map { MathChallengeFactory.challenge(for: mittens, friendship: $0) }

        XCTAssertTrue(challenges.allSatisfy { $0.visualHint.contains(mittens.storyIcon) })
        XCTAssertTrue(challenges.allSatisfy { $0.prompt.contains(mittens.name) })
        XCTAssertTrue(challenges.contains { $0.prompt.contains(mittens.storyItemPlural) })
        XCTAssertFalse(challenges.contains { $0.visualHint.contains("🧶") })
    }

    func testEachCatHasAProgressivelyRevealedFourPartBackstory() {
        for cat in CatContent.cats {
            XCTAssertEqual(cat.backstory.count, 4, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 0).count, 1, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 2).count, 3, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 20).count, 4, cat.id)
            XCTAssertEqual(Set(cat.backstory.map(\.id)).count, 4, cat.id)
        }
    }

    func testCareRewardsPersistAndOldProgressStillDecodes() throws {
        let oldSave = Data(#"{"friendship":{"mittens":2},"completedActivities":2,"journaledCatIDs":["mittens"],"selectedLocationID":"house"}"#.utf8)
        let decoded = try JSONDecoder().decode(CatProgress.self, from: oldSave)
        XCTAssertEqual(decoded.friendship["mittens"], 2)
        XCTAssertTrue(decoded.treatsGiven.isEmpty)

        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = CatGameStore(baseDirectory: base)
        first.load()
        let mittens = CatContent.cats.first { $0.id == "mittens" }!
        first.record(.treat, for: mittens)
        first.record(.meal, for: mittens)
        first.record(.trick, for: mittens)

        let restored = CatGameStore(baseDirectory: base)
        restored.load()
        XCTAssertEqual(restored.rewardCount(.treat, for: mittens), 1)
        XCTAssertEqual(restored.rewardCount(.meal, for: mittens), 1)
        XCTAssertEqual(restored.rewardCount(.trick, for: mittens), 1)
    }

    func testReleaseIdentityIsIndependent() {
        let config = CatAppConfiguration.value
        XCTAssertEqual(config.identity.applicationIdentifier, "com.mkilgore.CatMathAdventure")
        XCTAssertEqual(config.identity.childFacingName, "Kate’s Cat Math Adventure")
        XCTAssertEqual(config.storageNamespace, "com.mkilgore.CatMathAdventure.kate")
        XCTAssertEqual(config.narration.bundledManifestName, "cat-audio-manifest")
    }
}
