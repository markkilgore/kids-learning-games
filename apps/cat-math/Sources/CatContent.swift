import Foundation
import LearningEngine

struct CatStoryBeat: Identifiable, Hashable {
    let id: String
    let title: String
    /// The school reading unit this page practises; see `ReadingFocus` and cat-reading.json.
    let focusID: String
    /// One story page, a few sentences long. Each sentence is recorded and read aloud on its own.
    let sentences: [String]
    let puzzleLead: String

    var story: String { sentences.joined(separator: " ") }
}

struct CatDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let color: String
    let locationID: String
    let favoriteThing: String
    let unlockAt: Int
    let storyItem: String
    let storyItemPlural: String
    let storyIcon: String
    let trickName: String
    let trickSymbol: String
    let backstory: [CatStoryBeat]

    /// Puzzles in one round. A round is set in one story page and ends with a celebration.
    static let puzzlesPerRound = 3

    /// Pages in the first chapter. They open one round apart from the very first puzzle.
    static let chapterOnePages = 4

    /// The friendship level at which chapter two (page 5 onward) begins. The meadow animals carry straight on
    /// after chapter one. The ten cats' second chapter was written after Kate had reached 25 hearts with each of
    /// them, so theirs starts at 27: the pages open one round at a time instead of all at once.
    var chapterTwoStart: Int { locationID == "meadow" ? Self.chapterOnePages * Self.puzzlesPerRound : 27 }

    func isInChapterTwo(at friendship: Int) -> Bool { backstory.count > Self.chapterOnePages && friendship >= chapterTwoStart }

    /// The friendship level that opens a page.
    func friendshipNeeded(forPage page: Int) -> Int {
        page < Self.chapterOnePages ? page * Self.puzzlesPerRound : chapterTwoStart + (page - Self.chapterOnePages) * Self.puzzlesPerRound
    }

    /// The story page a cat is on: a new page opens each time a round of puzzles is finished.
    func storyPage(for friendship: Int) -> Int {
        (0..<backstory.count).last { friendshipNeeded(forPage: $0) <= max(friendship, 0) } ?? 0
    }

    func storyBeat(for friendship: Int) -> CatStoryBeat { backstory[storyPage(for: friendship)] }

    func revealedStory(for friendship: Int) -> [CatStoryBeat] {
        Array(backstory.prefix(storyPage(for: friendship) + 1))
    }

    /// Puzzles already solved in the round this friendship level is part of.
    func solvedInRound(for friendship: Int) -> Int { max(friendship, 0) % Self.puzzlesPerRound }

    /// The friendship level at which the last story page opens.
    var lastPageFriendship: Int { friendshipNeeded(forPage: backstory.count - 1) }

    /// Puzzles still to solve before the next page opens, or nil once every page is open.
    func puzzlesUntilNextPage(for friendship: Int) -> Int? {
        let next = storyPage(for: friendship) + 1
        return next < backstory.count ? friendshipNeeded(forPage: next) - max(friendship, 0) : nil
    }

    /// Whether finishing the round that starts at this friendship level opens a page.
    func roundOpensPage(from friendship: Int) -> Bool {
        storyPage(for: friendship + Self.puzzlesPerRound) > storyPage(for: friendship)
    }
}

enum CatContent {
    static let locations = [
        LearningLocation(id: "house", name: "House", symbol: "house.fill"),
        LearningLocation(id: "garden", name: "Garden", symbol: "leaf.fill"),
        LearningLocation(id: "meadow", name: "Meadow", symbol: "sun.max.fill")
    ]

    /// Every friend and their story, from cat-friends.json. The audio generator reads the same file.
    static let cats: [CatDefinition] = {
        struct File: Decodable {
            struct Friend: Decodable {
                struct Page: Decodable {
                    let title: String
                    let focusID: String
                    let sentences: [String]
                    let puzzleLead: String
                }

                let id, name, symbol, color, locationID, favoriteThing: String
                let unlockAt: Int
                let storyItem, storyItemPlural, storyIcon, trickName, trickSymbol: String
                let pages: [Page]
            }

            let friends: [Friend]
        }
        guard let url = Bundle.main.url(forResource: "cat-friends", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.friends.map { friend in
            CatDefinition(
                id: friend.id,
                name: friend.name,
                symbol: friend.symbol,
                color: friend.color,
                locationID: friend.locationID,
                favoriteThing: friend.favoriteThing,
                unlockAt: friend.unlockAt,
                storyItem: friend.storyItem,
                storyItemPlural: friend.storyItemPlural,
                storyIcon: friend.storyIcon,
                trickName: friend.trickName,
                trickSymbol: friend.trickSymbol,
                backstory: friend.pages.enumerated().map { index, page in
                    CatStoryBeat(id: "\(friend.id)-\(index)", title: page.title, focusID: page.focusID, sentences: page.sentences, puzzleLead: page.puzzleLead)
                }
            )
        }
    }()

    static let skills = [
        EducationalSkill(id: "counting", displayName: "Counting"),
        EducationalSkill(id: "addition", displayName: "Addition"),
        EducationalSkill(id: "subtraction", displayName: "Subtraction"),
        EducationalSkill(id: "odd-even", displayName: "Odd and even"),
        EducationalSkill(id: "skip-5", displayName: "Skip counting by 5"),
        EducationalSkill(id: "skip-10", displayName: "Skip counting by 10"),
        EducationalSkill(id: "doubles", displayName: "Doubles"),
        EducationalSkill(id: "skip-2", displayName: "Skip counting by 2")
    ]

    /// The six skills each chapter rotates through. Chapter two uses bigger numbers and swaps in doubles and twos.
    static let chapterOneSkillIDs = ["counting", "addition", "subtraction", "odd-even", "skip-5", "skip-10"]
    static let chapterTwoSkillIDs = ["addition", "subtraction", "doubles", "odd-even", "skip-2", "skip-5"]
}

enum CatAppConfiguration {
    static let value = LearningAppConfiguration(
        identity: AppIdentity(applicationIdentifier: "com.mkilgore.CatMathAdventure", displayName: "Cat Math Adventure", childFacingName: "Kate’s Cat Math Adventure", iconAssetName: "CatAppIcon", splashAssetName: "CatSplash"),
        theme: ThemeTokens(background: ["#FFF4D6", "#FADADD", "#CDECEF"], primary: "#A855F7", secondary: "#F97316", success: "#22C55E", surface: "#FFF9EE"),
        contentPack: ContentPackDescriptor(id: "kate-cat-math", version: 1, resourceName: "cat-catalog"),
        locations: CatContent.locations,
        characters: CatContent.cats.map { LearningCharacter(id: $0.id, name: $0.name, locationID: $0.locationID) },
        enabledSkills: CatContent.skills,
        narration: NarrationSettings(language: "en-US", normalRate: 0.46, slowRate: 0.36, pitch: 1.08, bundledManifestName: "cat-audio-manifest"),
        rewards: RewardVocabulary(singular: "friendship heart", plural: "friendship hearts", celebration: "Your friendship grew!"),
        progression: ProgressionRules(model: "friendship", pointsPerSuccess: 1, unlockThresholds: [0, 4, 6, 9, 12, 18, 100, 150, 255, 265, 280]),
        storageNamespace: "com.mkilgore.CatMathAdventure.kate",
        featureFlags: FeatureFlags(["journal": true, "visualHints": true, "narratedPrompts": true])
    )
}
