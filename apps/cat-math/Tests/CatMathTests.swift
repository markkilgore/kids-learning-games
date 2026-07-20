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

    func testReleaseIdentityIsIndependent() {
        let config = CatAppConfiguration.value
        XCTAssertEqual(config.identity.applicationIdentifier, "com.mkilgore.CatMathAdventure")
        XCTAssertEqual(config.identity.childFacingName, "Kate’s Cat Math Adventure")
        XCTAssertEqual(config.storageNamespace, "com.mkilgore.CatMathAdventure.kate")
    }
}
