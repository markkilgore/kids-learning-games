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
        XCTAssertEqual(CatContent.locations.map(\.id), ["house", "garden", "meadow"])
        XCTAssertEqual(CatContent.cats.count, 15)
        XCTAssertEqual(CatContent.cats.filter { $0.locationID == "meadow" }.count, 5)
        XCTAssertEqual(Set(CatAppConfiguration.value.enabledSkills.map(\.id)), ["counting", "addition", "subtraction", "odd-even", "skip-5", "skip-10", "doubles", "skip-2", "reading"])
        for cat in CatContent.cats {
            XCTAssertNotNil(UIImage(named: cat.artName), "no portrait for \(cat.id)")
            XCTAssertNotNil(UIImage(named: cat.countingArtName), "no counting picture for \(cat.id)")
        }
        for location in CatContent.locations { XCTAssertNotNil(UIImage(named: "backdrop-\(location.id)"), location.id) }
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

    /// Story pages are written for the reading units from school: each must really practise its unit.
    func testEveryStoryPagePractisesItsSchoolReadingUnit() throws {
        XCTAssertEqual(ReadingFocus.all.count, 5)
        var sightWordsUsed: [String: Set<String>] = [:]
        for cat in CatContent.cats {
            for page in cat.backstory {
                let focus = try XCTUnwrap(page.focus, "\(page.id) names an unknown unit \(page.focusID)")
                XCTAssertEqual(page.sentences.count, 4, page.id)
                let words = page.sentences.flatMap(\.wordTokens).map(\.text)
                let pattern = Set(words.filter { focus.kind(of: $0) == .pattern }.map(ReadingFocus.normalized))
                let sight = Set(words.filter { focus.kind(of: $0) == .sight }.map(ReadingFocus.normalized))
                XCTAssertGreaterThanOrEqual(pattern.count, 3, "\(page.id) needs more \(focus.title): \(pattern)")
                XCTAssertGreaterThanOrEqual(sight.count, 2, "\(page.id) needs more sight words: \(sight)")
                sightWordsUsed[focus.id, default: []].formUnion(sight)
            }
        }
        for focus in ReadingFocus.all {
            XCTAssertEqual(sightWordsUsed[focus.id], Set(focus.sightWords), "every sight word of \(focus.title) should appear in a story")
        }
        XCTAssertEqual(ReadingFocus.newest?.id, "l-blends")
        let ch = try XCTUnwrap(ReadingFocus.unit("ch"))
        XCTAssertEqual(ch.kind(of: "Chair"), .pattern)
        XCTAssertEqual(ch.kind(of: "today"), .sight)
        XCTAssertNil(ch.kind(of: "cat"))
        XCTAssertEqual(ReadingFocus.unit("s-blends")?.kind(of: "Don’t"), .sight)
        XCTAssertNil(ReadingFocus.unit("th-wh")?.kind(of: "the"))
    }

    func testEachCatHasAProgressivelyRevealedFourPartBackstory() {
        for cat in CatContent.cats {
            XCTAssertEqual(cat.backstory.count, 8, cat.id)
            // A page opens each time a round of three puzzles is finished.
            XCTAssertEqual(cat.revealedStory(for: 0).count, 1, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 2).count, 1, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 3).count, 2, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 8).count, 3, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 9).count, 4, cat.id)
            // Chapter two opens a page a round from its start: 27 hearts for the cats, 12 for the meadow animals.
            let start = cat.chapterTwoStart
            XCTAssertEqual(start, cat.locationID == "meadow" ? 12 : 27, cat.id)
            XCTAssertEqual(cat.revealedStory(for: start - 1).count, 4, cat.id)
            XCTAssertEqual(cat.revealedStory(for: start).count, 5, cat.id)
            XCTAssertEqual(cat.revealedStory(for: start + 8).count, 7, cat.id)
            XCTAssertEqual(cat.revealedStory(for: start + 9).count, 8, cat.id)
            XCTAssertEqual(cat.revealedStory(for: 200).count, 8, cat.id)
            XCTAssertEqual(cat.lastPageFriendship, start + 9, cat.id)
            XCTAssertEqual(cat.puzzlesUntilNextPage(for: 9), start - 9, cat.id)
            XCTAssertEqual(cat.puzzlesUntilNextPage(for: start + 1), 2, cat.id)
            XCTAssertNil(cat.puzzlesUntilNextPage(for: start + 9), cat.id)
            XCTAssertTrue(cat.roundOpensPage(from: start - 3), cat.id)
            XCTAssertFalse(cat.roundOpensPage(from: start + 9), cat.id)
            for friendship in start..<(start + 30) {
                let challenge = MathChallengeFactory.challenge(for: cat, friendship: friendship)
                XCTAssertTrue(CatContent.chapterTwoSkillIDs.contains(challenge.skill.id), challenge.prompt)
                XCTAssertTrue(challenge.prompt.hasPrefix(cat.storyBeat(for: friendship).puzzleLead), challenge.prompt)
                XCTAssertTrue((1...100).contains(challenge.answer) && challenge.choices.contains(challenge.answer), challenge.prompt)
                switch challenge.visual {
                case .add(let first, let second): XCTAssertLessThanOrEqual(first + second, 20, challenge.prompt)
                case .subtract(let total, let taken): XCTAssertTrue(total <= 20 && taken < total, challenge.prompt)
                case .makeTen(let total, let taken):
                    // School's "make a ten": the take-away always crosses ten, and the answer matches the frames.
                    XCTAssertTrue((11...18).contains(total) && taken > total - 10 && taken <= 9, challenge.prompt)
                    XCTAssertEqual(challenge.answer, total - taken, challenge.prompt)
                    XCTAssertEqual(challenge.skill.id, "subtraction")
                case .pairs(let total): XCTAssertLessThanOrEqual(total, 16, challenge.prompt)
                default: break
                }
            }
            XCTAssertEqual(cat.solvedInRound(for: 7), 1, cat.id)
            // Every puzzle in a round is set in that round's story scene.
            for friendship in 0..<12 {
                let lead = cat.storyBeat(for: friendship).puzzleLead
                XCTAssertTrue(MathChallengeFactory.challenge(for: cat, friendship: friendship).prompt.hasPrefix(lead), cat.id)
                XCTAssertEqual(lead, cat.backstory[friendship / 3].puzzleLead, cat.id)
            }
            XCTAssertEqual(Set(cat.backstory.map(\.id)).count, 8, cat.id)
            XCTAssertEqual(Set(cat.backstory.map(\.puzzleLead)).count, 8, cat.id)
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

    func testProgressSavedBeforeSkillStatsStillDecodes() throws {
        let oldSave = Data(#"{"friendship":{"mittens":3},"completedActivities":3,"journaledCatIDs":["mittens"],"selectedLocationID":"garden","treatsGiven":{"mittens":1},"mealsServed":{},"tricksPerformed":{}}"#.utf8)
        let decoded = try JSONDecoder().decode(CatProgress.self, from: oldSave)
        XCTAssertEqual(decoded.friendship["mittens"], 3)
        XCTAssertEqual(decoded.selectedLocationID, "garden")
        XCTAssertTrue(decoded.skillStats.isEmpty)

        // A stats entry missing newer fields decodes with defaults.
        let partial = Data(#"{"skillStats":{"addition":{"attempts":2,"firstTryCorrect":1}}}"#.utf8)
        let stats = try XCTUnwrap(JSONDecoder().decode(CatProgress.self, from: partial).skillStats["addition"])
        XCTAssertEqual(stats.attempts, 2)
        XCTAssertEqual(stats.firstTryCorrect, 1)
        XCTAssertEqual(stats.wrongAnswers, 0)
        XCTAssertEqual(stats.difficulty, 0)
        XCTAssertNil(stats.lastPractised)
    }

    func testAnswersAreRecordedPerSkillAndPersist() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let game = CatGameStore(baseDirectory: base)
        game.load()
        let skills = CatAppConfiguration.value.enabledSkills
        let addition = try XCTUnwrap(skills.first { $0.id == "addition" })
        let counting = try XCTUnwrap(skills.first { $0.id == "counting" })
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        game.recordAnswer(for: addition, correct: false, isFirstAnswer: true, on: day)
        game.recordAnswer(for: addition, correct: true, isFirstAnswer: false, on: day)
        game.recordAnswer(for: addition, correct: true, isFirstAnswer: true, on: day)
        game.recordAnswer(for: counting, correct: true, isFirstAnswer: true, on: day)

        let restored = CatGameStore(baseDirectory: base)
        restored.load()
        let stats = restored.stats(for: addition)
        XCTAssertEqual(stats.attempts, 2)
        XCTAssertEqual(stats.firstTryCorrect, 1)
        XCTAssertEqual(stats.wrongAnswers, 1)
        XCTAssertEqual(stats.lastPractised, day)
        XCTAssertEqual(stats.firstTryAccuracy, 0.5)
        XCTAssertEqual(restored.stats(for: counting).attempts, 1)
        XCTAssertEqual(restored.stats(for: try XCTUnwrap(skills.first { $0.id == "skip-5" })), SkillPracticeStats())

        restored.resetProgress()
        XCTAssertTrue(restored.progress.skillStats.isEmpty)
    }

    func testDifficultyStepsUpAfterAFirstTryStreakAndDownAfterRepeatedMisses() {
        let day = Date(timeIntervalSince1970: 0)
        var stats = SkillPracticeStats()
        stats.record(correct: true, isFirstAnswer: true, on: day)
        stats.record(correct: true, isFirstAnswer: true, on: day)
        XCTAssertEqual(stats.difficulty, 0)
        stats.record(correct: true, isFirstAnswer: true, on: day)
        XCTAssertEqual(stats.difficulty, 1, "three first-try answers in a row step up")
        for _ in 0..<3 { stats.record(correct: true, isFirstAnswer: true, on: day) }
        XCTAssertEqual(stats.difficulty, 1, "difficulty never goes above +1")

        // A miss breaks the streak; a right answer on a second try neither counts towards it nor clears the misses.
        stats.record(correct: true, isFirstAnswer: true, on: day)
        stats.record(correct: false, isFirstAnswer: true, on: day)
        stats.record(correct: true, isFirstAnswer: false, on: day)
        stats.record(correct: true, isFirstAnswer: true, on: day)
        XCTAssertEqual(stats.difficulty, 1)
        XCTAssertEqual(stats.missStreak, 0, "a first-try success clears earlier misses")

        stats.record(correct: false, isFirstAnswer: true, on: day)
        stats.record(correct: false, isFirstAnswer: false, on: day)
        stats.record(correct: true, isFirstAnswer: false, on: day)
        XCTAssertEqual(stats.difficulty, 1)
        stats.record(correct: false, isFirstAnswer: true, on: day)
        XCTAssertEqual(stats.difficulty, 0, "three misses without a first-try success step down")
        for _ in 0..<3 { stats.record(correct: false, isFirstAnswer: true, on: day) }
        XCTAssertEqual(stats.difficulty, -1)
        for _ in 0..<6 { stats.record(correct: false, isFirstAnswer: true, on: day) }
        XCTAssertEqual(stats.difficulty, -1, "difficulty never goes below -1")
        XCTAssertTrue(stats.needsHelp)
        XCTAssertNotNil(CatProgressSection.note(stats))

        XCTAssertEqual(stats.attempts, 20)
        XCTAssertEqual(stats.wrongAnswers, 13)
        XCTAssertEqual(stats.firstTryCorrect, 8)
    }

    func testAdaptiveDifficultyOnlyRanksRecordedVariantsOfTheSameSkill() {
        var changed = 0
        for cat in CatContent.cats {
            for friendship in 0..<(cat.lastPageFriendship + 24) {
                let usual = MathChallengeFactory.challenge(for: cat, friendship: friendship)
                let easier = MathChallengeFactory.challenge(for: cat, friendship: friendship, difficulty: -1)
                let harder = MathChallengeFactory.challenge(for: cat, friendship: friendship, difficulty: 1)
                XCTAssertEqual(MathChallengeFactory.skill(for: cat, friendship: friendship), usual.skill)
                XCTAssertEqual(easier.skill, usual.skill)
                XCTAssertEqual(harder.skill, usual.skill)
                XCTAssertEqual(MathChallengeFactory.challenge(for: cat, friendship: friendship, difficulty: -5).prompt, easier.prompt)
                if friendship < cat.lastPageFriendship {
                    // Before the last story page each lead line has only one recorded prompt.
                    XCTAssertEqual(easier.prompt, usual.prompt)
                    XCTAssertEqual(harder.prompt, usual.prompt)
                    continue
                }
                XCTAssertLessThanOrEqual(size(easier), size(usual), easier.prompt)
                XCTAssertGreaterThanOrEqual(size(harder), size(usual), harder.prompt)
                // The variant is a prompt the usual rotation also produces for this cat.
                let recorded = Set((0..<(cat.lastPageFriendship + 18)).map { MathChallengeFactory.challenge(for: cat, friendship: $0).prompt })
                XCTAssertTrue(recorded.contains(easier.prompt))
                XCTAssertTrue(recorded.contains(harder.prompt))
                if easier.prompt != usual.prompt || harder.prompt != usual.prompt { changed += 1 }
            }
        }
        XCTAssertGreaterThan(changed, 100, "difficulty should change most puzzles once the story is unlocked")
    }

    private func size(_ challenge: MathChallenge) -> Int {
        switch challenge.visual {
        case .count(let total), .pairs(let total), .subtract(let total, _), .makeTen(let total, _): total
        case .add(let first, let second): first + second
        case .sequence(let numbers): numbers.last ?? 0
        }
    }

    /// After a story page the child hears one of its sentences and finds it among three from the same page.
    func testEveryStoryPageHasAReadingQuestion() throws {
        var generator = SystemRandomNumberGenerator()
        var answers = Set<String>()
        for cat in CatContent.cats {
            for page in cat.backstory {
                for _ in 0..<6 {
                    let question = try XCTUnwrap(ReadingQuestion.question(for: page, using: &generator), page.id)
                    XCTAssertEqual(Set(question.choices).count, 3, page.id)
                    XCTAssertTrue(question.choices.contains(question.sentence), page.id)
                    XCTAssertTrue(question.choices.allSatisfy(page.sentences.contains), page.id)
                    answers.insert(question.sentence)
                }
            }
        }
        // The sentence asked for changes from visit to visit.
        XCTAssertGreaterThan(answers.count, CatContent.cats.count * 8 * 2)
        let short = CatStoryBeat(id: "short", title: "", focusID: "", sentences: ["One.", "Two."], puzzleLead: "")
        XCTAssertNil(ReadingQuestion.question(for: short, using: &generator))
    }

    /// Every line the app can speak must have a bundled recording, or it falls back to the robotic device voice.
    func testEverySpokenLineHasARecording() throws {
        let manifest = AudioManifest(bundle: .main, resourceName: CatAppConfiguration.value.narration.bundledManifestName)
        var lines = WeeklySpokenLines.all + CatLine.allCases.map(\.text)
        for cat in CatContent.cats {
            lines += cat.backstory.flatMap(\.sentences) + CatRewardAction.allCases.map { $0.celebration(for: cat) }
            lines.append("You did it! \(cat.name)’s friendship grew.")
            for difficulty in SkillPracticeStats.difficultyRange {
                lines += (0..<80).map { MathChallengeFactory.challenge(for: cat, friendship: $0, difficulty: difficulty).prompt }
            }
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
