import XCTest
import Narration
@testable import LearningUI
@testable import CatMathAdventure

@MainActor
final class CatMathTests: XCTestCase {
    func testWeeklyShelfDatesAndNewRecaps() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "cat-weeks", withExtension: "json"))
        let weeks = try JSONDecoder().decode([LessonWeek].self, from: Data(contentsOf: url))
        let original = weeks.filter { $0.start <= "2026-11-09" }
        for day in ["2026-11-09", "2026-11-15", "2026-11-23"] {
            let available = LessonWeek.available(in: original, on: day)
            XCTAssertEqual(available.map(\.start), ["2026-11-09", "2026-11-02", "2026-10-26", "2026-10-19"])
            XCTAssertEqual(available.first?.homeTitle(on: day), day == "2026-11-23" ? "Latest Week" : "This Week")
        }
        let extra = LessonWeek(start: "2026-11-16", end: "2026-11-22", dates: "Nov 16–22", overview: "", activities: [])
        XCTAssertEqual(LessonWeek.available(in: original + [extra], on: "2026-11-16").prefix(2).map(\.start),
                       ["2026-11-16", "2026-11-09"])
    }

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

    func testCorrectAnswerMovesBetweenPositionsAndWrongAnswersVary() {
        let mittens = CatContent.cats[0]
        var positions = Set<Int>(), wrongAnswers = Set<Int>()
        for _ in 0..<60 {
            let challenge = MathChallengeFactory.challenge(for: mittens, friendship: 0)
            XCTAssertEqual(challenge.choices.count, 3)
            XCTAssertEqual(Set(challenge.choices).count, 3)
            XCTAssertTrue(challenge.choices.allSatisfy { $0 > 0 })
            positions.insert(challenge.choices.firstIndex(of: challenge.answer)!)
            wrongAnswers.formUnion(challenge.choices.filter { $0 != challenge.answer })
        }
        XCTAssertEqual(positions, [0, 1, 2], "the correct answer must not always sit in the same place")
        XCTAssertGreaterThan(wrongAnswers.count, 2)
    }

    func testOddEvenUsesWordsAndSkipCountingVaries() {
        var skipAnswers = Set<Int>()
        for cat in CatContent.cats {
            for friendship in 0..<36 {
                let challenge = MathChallengeFactory.challenge(for: cat, friendship: friendship)
                switch challenge.skill.id {
                case "odd-even":
                    XCTAssertEqual(Set(challenge.choices.map(challenge.label)), ["Odd", "Even"])
                    XCTAssertFalse(challenge.prompt.contains("Choose 1"))
                case "skip-5":
                    skipAnswers.insert(challenge.answer)
                    XCTAssertTrue(challenge.answer.isMultiple(of: 5))
                case "subtraction":
                    XCTAssertFalse(challenge.prompt.contains(" 1 are "), challenge.prompt)
                default: break
                }
            }
        }
        XCTAssertGreaterThan(skipAnswers.count, 1)
    }

    func testSolvingReportsNewFriendsAndResetClearsProgress() {
        let game = CatGameStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        game.load()
        let mittens = CatContent.cats[0], poppy = CatContent.cats.first { $0.id == "poppy" }!
        XCTAssertEqual(game.heartsNeeded(for: poppy), 4)
        var unlocked: [CatDefinition] = []
        for _ in 0..<4 { unlocked += game.completeActivity(for: mittens) }
        XCTAssertEqual(unlocked.map(\.id), ["poppy"])
        XCTAssertTrue(game.isUnlocked(poppy))
        game.resetProgress()
        XCTAssertEqual(game.totalFriendship, 0)
        XCTAssertFalse(game.isUnlocked(poppy))
    }

    /// Every line the app can speak must have a bundled recording, or it falls back to the robotic device voice.
    func testEverySpokenLineHasARecording() throws {
        let manifest = AudioManifest(bundle: .main, resourceName: CatAppConfiguration.value.narration.bundledManifestName)
        var lines = WeeklySpokenLines.all + CatLine.allCases.map(\.text)
        for cat in CatContent.cats {
            lines += cat.backstory.map(\.story) + CatRewardAction.allCases.map { $0.celebration(for: cat) }
            lines.append("You did it! \(cat.name)’s friendship grew.")
            lines += (0..<80).map { MathChallengeFactory.challenge(for: cat, friendship: $0).prompt }
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "cat-weeks", withExtension: "json"))
        for week in try JSONDecoder().decode([LessonWeek].self, from: Data(contentsOf: url)) {
            lines.append(week.overview)
            lines += week.activities.flatMap(\.steps).flatMap { [$0.spoken ?? $0.prompt, $0.hint] }
        }
        XCTAssertFalse(lines.contains(""), "a CatLine key is missing from ui-lines.json")
        let missing = Set(lines).filter { manifest.clipURL(for: $0) == nil }
        XCTAssertEqual(missing.sorted(), [], "run `npm --prefix tools run cat-audio`")
    }
}
