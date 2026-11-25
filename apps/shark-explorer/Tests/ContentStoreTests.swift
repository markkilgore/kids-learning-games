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
        XCTAssertEqual(catalog.sharks.count, 20)
        XCTAssertEqual(catalog.sharks.flatMap(\.topics).count, 140)
        XCTAssertEqual(catalog.sharks.flatMap(\.questions).count, 60)
        XCTAssertGreaterThanOrEqual(catalog.vocabulary.count, 30)
        XCTAssertTrue(catalog.vocabulary.allSatisfy { word in catalog.sharks.contains { $0.vocabularyIDs.contains(word.id) } })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.count == 7 })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.topics.allSatisfy { $0.id != "babies" } })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.questions.count == 3 })
        XCTAssertTrue(catalog.sharks.allSatisfy { $0.traits.count >= 2 })
        XCTAssertTrue(catalog.sharks.allSatisfy { shark in
            shark.traits.allSatisfy { shark.topics.map(\.id).contains($0.unlockTopicID) }
        })
    }

    func testEveryMissionKindHasItsTargetPicture() throws {
        for shark in ContentStore.shared.catalog.sharks {
            let play = try XCTUnwrap(MissionPlay.byKind[shark.mission.kind], "\(shark.id): no play set-up for mission kind \(shark.mission.kind)")
            if let asset = play.targetAsset {
                XCTAssertNotNil(UIImage(named: asset), "\(shark.id): missing target picture \(asset)")
            }
            XCTAssertGreaterThan(shark.mission.targetCount, 0, shark.id)
            XCTAssertFalse(shark.mission.completion.isEmpty, shark.id)
            XCTAssertNotNil(UIImage(systemName: shark.mission.symbol), "\(shark.id): unknown SF Symbol \(shark.mission.symbol)")
        }
        // No kind is defined that the catalog never uses.
        XCTAssertEqual(Set(MissionPlay.byKind.keys), Set(ContentStore.shared.catalog.sharks.map(\.mission.kind)))
    }

    func testEveryQuizChoiceOfTheNewSharksHasAPicture() throws {
        let firstTen: Set = ["whale", "hammerhead", "nurse", "great-white", "wobbegong", "thresher", "tiger", "epaulette", "goblin", "greenland"]
        for shark in ContentStore.shared.catalog.sharks where !firstTen.contains(shark.id) {
            for choice in shark.questions.flatMap(\.choices) {
                XCTAssertNotNil(UIImage(named: QuestionRoundView.artName(for: choice)), "\(shark.id): no picture for choice \(choice.id)")
            }
        }
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

    func testSecondTenSharksStayLockedUntilTheFirstTenAreDoneThenOpenOneByOne() throws {
        let game = GameStore()
        let sharks = ContentStore.shared.catalog.sharks
        let order = sharks.sorted { $0.unlockAt < $1.unlockAt }
        game.completedSharks = Set(order.prefix(9).map(\.id))
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 10)
        for done in 10..<sharks.count {
            game.completedSharks = Set(order.prefix(done).map(\.id))
            XCTAssertGreaterThan(sharks.filter(game.isUnlocked).count, done, "nothing left to play after \(done) missions")
        }
        game.completedSharks = Set(order.prefix(10).map(\.id))
        XCTAssertEqual(sharks.filter(game.isUnlocked).count, 12)
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

    /// The sound-it-out sentences must use only letters Henry has been taught, plus heart words.
    func testDecodableSentencesUseOnlyTaughtLettersAndHeartWords() throws {
        let reading = SharkReading.shared
        XCTAssertEqual(reading.letters.count, 18)
        XCTAssertEqual(reading.mark("fins"), .decodable)
        XCTAssertEqual(reading.mark("Hid"), .featured)
        XCTAssertEqual(reading.mark("the"), .heart)
        XCTAssertNil(reading.mark("shark"))
        XCTAssertNil(reading.mark("her"))
        XCTAssertNil(reading.mark("he"))
        XCTAssertNil(reading.mark("jaw"))

        var featured = 0
        for shark in ContentStore.shared.catalog.sharks {
            let narratives = [shark.discover] + shark.topics.map(\.narration)
            XCTAssertNotNil(shark.discover.decodable, shark.id)
            for sentence in narratives.flatMap({ $0.decodable ?? [] }) {
                XCTAssertEqual(shark.discover.sentences(for: .story).contains(sentence), false)
                for token in sentence.wordTokens {
                    let mark = reading.mark(token.text)
                    XCTAssertNotNil(mark, "\(shark.id): Henry cannot read \"\(token.text)\" yet in \"\(sentence)\"")
                    if mark == .featured { featured += 1 }
                }
            }
            XCTAssertEqual(shark.discover.sentences(for: .earlyReader).first, shark.discover.decodable?.first)
        }
        XCTAssertGreaterThan(featured, 30, "the newest letters should get plenty of practice")
    }

    func testMissionRoundsPractiseNumbersAndThisSharksOwnWordsAtEveryLevel() throws {
        let sharks = ContentStore.shared.catalog.sharks
        let reading = SharkReading.shared
        let spoken = Set(MissionChallenges.allSpokenLines(sharks: sharks, reading: reading))
        var generator = SeededRandomNumberGenerator(seed: 7)
        for shark in sharks {
            let mine = MissionChallenges.readingWords(in: [shark], reading: reading)
            for level in 1...MissionChallenges.maxLevel {
                for _ in 0..<12 {
                    let rounds = MissionChallenges.rounds(for: shark, level: level, sharks: sharks, reading: reading, using: &generator)
                    XCTAssertEqual(rounds.count, shark.mission.targetCount, shark.id)
                    XCTAssertTrue(rounds.contains { $0.area == .math } && rounds.contains { $0.area == .words }, "\(shark.id) level \(level) needs both numbers and words")
                    for round in rounds {
                        XCTAssertTrue(spoken.contains(round.spoken), round.spoken)
                        XCTAssertTrue((2...3).contains(round.choices.count), "\(shark.id): \(round.spoken) \(round.choices)")
                        XCTAssertEqual(round.choices.count, round.choices.reduce(into: [MissionChallenge.Choice]()) { if !$0.contains($1) { $0.append($1) } }.count, "repeated choice in \(round.spoken)")
                        let right = round.choices[round.answer]
                        switch right {
                        case .group(let count):
                            XCTAssertTrue((1...10).contains(count))
                            if round.spoken == MissionChallenges.moreLine { XCTAssertTrue(round.choices.allSatisfy { if case .group(let other) = $0 { other <= count } else { false } }) }
                            if round.spoken == MissionChallenges.fewerLine { XCTAssertTrue(round.choices.allSatisfy { if case .group(let other) = $0 { other >= count } else { false } }) }
                            if round.spoken != MissionChallenges.moreLine, round.spoken != MissionChallenges.fewerLine { XCTAssertEqual(round.spoken, MissionChallenges.countLine(count)) }
                        case .numeral(let number):
                            XCTAssertTrue((1...10).contains(number))
                            XCTAssertTrue([MissionChallenges.numeralLine(number), MissionChallenges.oneMoreLine(number - 1), MissionChallenges.oneLessLine(number + 1)].contains(round.spoken), round.spoken)
                        case .word(let word):
                            XCTAssertEqual(round.spoken, MissionChallenges.wordLine(word))
                            XCTAssertTrue((mine.decodable + mine.heart).contains(word), "\(shark.id): \(word) is not in this shark's sentences")
                            XCTAssertEqual(round.shown, MissionChallenges.listenPrompt, "the word must be read, not matched to the prompt")
                            for case .word(let other) in round.choices { XCTAssertNotNil(reading.mark(other), "Henry cannot read \(other) yet") }
                        }
                    }
                }
            }
        }
    }

    func testStarsNeedRoundsRightFirstTimeAndOlderProgressCountsAsOneStar() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = try NamespacedProgressStore<SharkProgress>(namespace: "test.stars", baseDirectory: directory)
        try storage.save(SharkProgress(completedSharks: ["whale"]))
        let game = GameStore(progressStore: storage)
        game.load()
        let whale = try XCTUnwrap(ContentStore.shared.catalog.sharks.first { $0.id == "whale" })
        let nurse = try XCTUnwrap(ContentStore.shared.catalog.sharks.first { $0.id == "nurse" })
        XCTAssertEqual(game.stars(for: whale), 1)
        XCTAssertEqual(game.missionLevel(for: whale), 2)
        XCTAssertEqual(game.stars(for: nurse), 0)
        XCTAssertEqual(game.missionLevel(for: nurse), 1)

        XCTAssertTrue(MissionChallenges.earnsStar(level: 1, firstTry: 0, rounds: 5))
        XCTAssertTrue(MissionChallenges.earnsStar(level: 2, firstTry: 4, rounds: 5))
        XCTAssertFalse(MissionChallenges.earnsStar(level: 2, firstTry: 3, rounds: 5))

        let missed = game.completeMission(for: whale, starLevel: 1)
        XCTAssertEqual(missed.stars, 1)
        XCTAssertFalse(missed.isNewStar)
        let earned = game.completeMission(for: whale, starLevel: 2)
        XCTAssertEqual(earned.stars, 2)
        XCTAssertTrue(earned.isNewStar)
        XCTAssertEqual(game.completeMission(for: whale, starLevel: 1).stars, 2, "stars are never lost")
        game.recordRound(.math, firstTry: true)
        game.recordRound(.words, firstTry: false)

        let reloaded = GameStore(progressStore: storage)
        reloaded.load()
        XCTAssertEqual(reloaded.stars(for: whale), 2)
        XCTAssertEqual(reloaded.missionLevel(for: whale), 3)
        XCTAssertEqual(reloaded.roundTally(for: .math).firstTry, 1)
        XCTAssertEqual(reloaded.roundTally(for: .words).retried, 1)
    }

    /// Every line the app can speak must have a bundled recording, or it falls back to the robotic device voice.
    func testEverySpokenLineHasARecording() throws {
        let manifest = AudioManifest(bundle: .main, resourceName: SharkAppConfiguration.value.narration.bundledManifestName)
        let catalog = ContentStore.shared.catalog
        var lines = WeeklySpokenLines.all + SharkLine.allCases.map(\.text) + catalog.vocabulary.map(\.word)
        lines += MissionChallenges.allSpokenLines(sharks: catalog.sharks, reading: .shared)
        for shark in catalog.sharks {
            let narratives = [shark.discover, shark.mission.instructions] + shark.topics.map(\.narration) + shark.questions.map(\.prompt)
            lines += narratives.flatMap { ($0.decodable ?? []) + $0.earlyReader + $0.story }
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
