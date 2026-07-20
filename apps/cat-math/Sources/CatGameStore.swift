import Foundation
import LearningPersistence
import Observation

struct CatProgress: Codable, Equatable {
    var friendship: [String: Int] = [:]
    var completedActivities: Int = 0
    var journaledCatIDs: Set<String> = []
    var selectedLocationID: String = "house"
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

    func showHome() { destination = .home }
    func showJournal() { destination = .journal }
    func showSettings() { destination = .settings }

    private func save() { try? progressStore.save(progress) }
}
