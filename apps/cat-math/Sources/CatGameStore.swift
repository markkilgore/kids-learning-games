import Foundation
import LearningEngine
import LearningPersistence
import Observation

struct CatProgress: Codable, Equatable {
    var friendship: [String: Int] = [:]
    var completedActivities: Int = 0
    var journaledCatIDs: Set<String> = []
    var selectedLocationID: String = "house"
    var treatsGiven: [String: Int] = [:]
    var mealsServed: [String: Int] = [:]
    var tricksPerformed: [String: Int] = [:]
    /// Practice record for each skill, keyed by skill ID. Added later, so older saves have none.
    var skillStats: [String: SkillPracticeStats] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendship = try container.decodeIfPresent([String: Int].self, forKey: .friendship) ?? [:]
        completedActivities = try container.decodeIfPresent(Int.self, forKey: .completedActivities) ?? 0
        journaledCatIDs = try container.decodeIfPresent(Set<String>.self, forKey: .journaledCatIDs) ?? []
        selectedLocationID = try container.decodeIfPresent(String.self, forKey: .selectedLocationID) ?? "house"
        treatsGiven = try container.decodeIfPresent([String: Int].self, forKey: .treatsGiven) ?? [:]
        mealsServed = try container.decodeIfPresent([String: Int].self, forKey: .mealsServed) ?? [:]
        tricksPerformed = try container.decodeIfPresent([String: Int].self, forKey: .tricksPerformed) ?? [:]
        skillStats = try container.decodeIfPresent([String: SkillPracticeStats].self, forKey: .skillStats) ?? [:]
    }
}

/// How one skill is going: what a parent sees, plus the streaks that drive adaptive difficulty.
struct SkillPracticeStats: Codable, Equatable {
    /// Puzzles answered (counted at the first answer to each puzzle).
    var attempts = 0
    /// Puzzles whose first answer was right.
    var firstTryCorrect = 0
    /// Every wrong answer, including a second wrong try on the same puzzle.
    var wrongAnswers = 0
    var lastPractised: Date?
    /// -1 easier numbers, 0 the usual rotation, +1 harder numbers.
    var difficulty = 0
    /// First-try-correct puzzles in a row since the last miss or step up.
    var firstTryStreak = 0
    /// Wrong answers since the last first-try-correct puzzle or step down.
    var missStreak = 0

    static let difficultyRange = -1...1
    /// This many first-try-correct puzzles in a row steps the skill one level harder.
    static let stepUpAfter = 3
    /// This many wrong answers without a first-try-correct puzzle in between steps it one level easier.
    static let stepDownAfter = 3

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        firstTryCorrect = try container.decodeIfPresent(Int.self, forKey: .firstTryCorrect) ?? 0
        wrongAnswers = try container.decodeIfPresent(Int.self, forKey: .wrongAnswers) ?? 0
        lastPractised = try container.decodeIfPresent(Date.self, forKey: .lastPractised)
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 0
        firstTryStreak = try container.decodeIfPresent(Int.self, forKey: .firstTryStreak) ?? 0
        missStreak = try container.decodeIfPresent(Int.self, forKey: .missStreak) ?? 0
    }

    var firstTryAccuracy: Double? { attempts == 0 ? nil : Double(firstTryCorrect) / Double(attempts) }

    /// Worth a parent's attention: difficulty has stepped down, or under half of several puzzles were right first time.
    var needsHelp: Bool {
        difficulty < 0 || (attempts >= 4 && (firstTryAccuracy ?? 1) < 0.5)
    }

    /// Records one tap on an answer. `isFirstAnswer` is true for the first tap on a puzzle.
    mutating func record(correct: Bool, isFirstAnswer: Bool, on date: Date) {
        lastPractised = date
        if isFirstAnswer { attempts += 1 }
        if correct {
            guard isFirstAnswer else { return }
            firstTryCorrect += 1
            missStreak = 0
            firstTryStreak += 1
            if firstTryStreak >= Self.stepUpAfter {
                difficulty = min(difficulty + 1, Self.difficultyRange.upperBound)
                firstTryStreak = 0
            }
        } else {
            wrongAnswers += 1
            firstTryStreak = 0
            missStreak += 1
            if missStreak >= Self.stepDownAfter {
                difficulty = max(difficulty - 1, Self.difficultyRange.lowerBound)
                missStreak = 0
            }
        }
    }
}

enum CatRewardAction: String, CaseIterable, Identifiable {
    case treat
    case meal
    case trick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .treat: "Give a treat"
        case .meal: "Fill the bowl"
        case .trick: "Ask for a trick"
        }
    }

    var symbol: String {
        switch self {
        case .treat: "fish.fill"
        case .meal: "takeoutbag.and.cup.and.straw.fill"
        case .trick: "sparkles"
        }
    }

    func celebration(for cat: CatDefinition) -> String {
        switch self {
        case .treat: "Crunch! \(cat.name) loved that tasty treat."
        case .meal: "Yum! \(cat.name) is happily eating from the bowl."
        case .trick: "Ta-da! \(cat.name) performed \(cat.trickName)!"
        }
    }
}

enum CatDestination: Hashable {
    case home
    case activity(String)
    case journal
    case settings
}

@MainActor
@Observable
final class CatGameStore {
    var destination: CatDestination = .home
    private(set) var progress = CatProgress()
    private let progressStore: NamespacedProgressStore<CatProgress>?
    private var didLoad = false

    /// UI tests pass `-heartsWithEveryCat 25` to start where a long-time player is, without touching saved progress.
    private static let heartsForTesting: Int? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-heartsWithEveryCat"), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }()

    init(baseDirectory: URL? = nil) {
        progressStore = Self.heartsForTesting == nil
            ? try? NamespacedProgressStore(namespace: CatAppConfiguration.value.storageNamespace, baseDirectory: baseDirectory)
            : nil
    }

    var totalFriendship: Int { progress.friendship.values.reduce(0, +) }
    var selectedLocationID: String {
        get { progress.selectedLocationID }
        set { progress.selectedLocationID = newValue; save() }
    }

    func load() {
        guard !didLoad else { return }
        didLoad = true
        progress = (try? progressStore?.load(default: CatProgress())) ?? CatProgress()
        if let hearts = Self.heartsForTesting {
            for cat in CatContent.cats where cat.locationID != "meadow" {
                progress.friendship[cat.id] = hearts
                progress.journaledCatIDs.insert(cat.id)
            }
        }
    }

    func friendship(for cat: CatDefinition) -> Int { progress.friendship[cat.id, default: 0] }
    func isUnlocked(_ cat: CatDefinition) -> Bool { friendship(for: cat) > 0 || totalFriendship >= cat.unlockAt }

    func open(_ cat: CatDefinition) {
        guard isUnlocked(cat) else { return }
        destination = .activity(cat.id)
    }

    /// How many more hearts, across all cats, bring a shy cat out.
    func heartsNeeded(for cat: CatDefinition) -> Int { max(0, cat.unlockAt - totalFriendship) }

    /// Records a solved puzzle and returns any cats the new heart just unlocked.
    @discardableResult
    func completeActivity(for cat: CatDefinition) -> [CatDefinition] {
        let lockedBefore = CatContent.cats.filter { !isUnlocked($0) }
        progress.friendship[cat.id, default: 0] += CatAppConfiguration.value.progression.pointsPerSuccess
        progress.completedActivities += 1
        progress.journaledCatIDs.insert(cat.id)
        save()
        return lockedBefore.filter(isUnlocked)
    }

    func stats(for skill: EducationalSkill) -> SkillPracticeStats { progress.skillStats[skill.id] ?? SkillPracticeStats() }

    /// The next puzzle with this cat, at the difficulty its skill has earned.
    func nextChallenge(for cat: CatDefinition) -> MathChallenge {
        let friendship = friendship(for: cat)
        let skill = MathChallengeFactory.skill(for: cat, friendship: friendship)
        return MathChallengeFactory.challenge(for: cat, friendship: friendship, difficulty: stats(for: skill).difficulty)
    }

    /// Records one answer tap for a puzzle's skill and adjusts that skill's difficulty.
    func recordAnswer(for skill: EducationalSkill, correct: Bool, isFirstAnswer: Bool, on date: Date = .now) {
        progress.skillStats[skill.id, default: SkillPracticeStats()].record(correct: correct, isFirstAnswer: isFirstAnswer, on: date)
        save()
    }

    func resetProgress() {
        let location = progress.selectedLocationID
        progress = CatProgress()
        progress.selectedLocationID = location
        save()
    }

    func record(_ reward: CatRewardAction, for cat: CatDefinition) {
        switch reward {
        case .treat:
            progress.treatsGiven[cat.id, default: 0] += 1
        case .meal:
            progress.mealsServed[cat.id, default: 0] += 1
        case .trick:
            progress.tricksPerformed[cat.id, default: 0] += 1
        }
        save()
    }

    func rewardCount(_ reward: CatRewardAction, for cat: CatDefinition) -> Int {
        switch reward {
        case .treat: progress.treatsGiven[cat.id, default: 0]
        case .meal: progress.mealsServed[cat.id, default: 0]
        case .trick: progress.tricksPerformed[cat.id, default: 0]
        }
    }

    func showHome() { destination = .home }
    func showJournal() { destination = .journal }
    func showSettings() { destination = .settings }

    private func save() { try? progressStore?.save(progress) }
}
