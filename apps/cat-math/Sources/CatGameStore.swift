import Foundation
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

enum CatDestination: Equatable {
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
    private let progressStore: NamespacedProgressStore<CatProgress>
    private var didLoad = false

    init(baseDirectory: URL? = nil) {
        progressStore = try! NamespacedProgressStore(namespace: CatAppConfiguration.value.storageNamespace, baseDirectory: baseDirectory)
    }

    var totalFriendship: Int { progress.friendship.values.reduce(0, +) }
    var selectedLocationID: String {
        get { progress.selectedLocationID }
        set { progress.selectedLocationID = newValue; save() }
    }

    func load() {
        guard !didLoad else { return }
        didLoad = true
        progress = (try? progressStore.load(default: CatProgress())) ?? CatProgress()
    }

    func friendship(for cat: CatDefinition) -> Int { progress.friendship[cat.id, default: 0] }
    func isUnlocked(_ cat: CatDefinition) -> Bool { friendship(for: cat) > 0 || totalFriendship >= cat.unlockAt }

    func open(_ cat: CatDefinition) {
        guard isUnlocked(cat) else { return }
        destination = .activity(cat.id)
    }

    func completeActivity(for cat: CatDefinition) {
        progress.friendship[cat.id, default: 0] += CatAppConfiguration.value.progression.pointsPerSuccess
        progress.completedActivities += 1
        progress.journaledCatIDs.insert(cat.id)
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

    private func save() { try? progressStore.save(progress) }
}
