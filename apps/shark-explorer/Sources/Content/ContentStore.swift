import Foundation

enum ContentError: LocalizedError {
    case missingCatalog
    case invalidCatalog(String)

    var errorDescription: String? {
        switch self {
        case .missingCatalog: "The bundled shark catalog is missing."
        case .invalidCatalog(let reason): "The shark catalog is invalid: \(reason)"
        }
    }
}

@MainActor
final class ContentStore {
    static let shared = ContentStore()
    let catalog: GameCatalog
    /// Set when the bundled catalog could not be read; the app then shows a message instead of the map.
    let loadError: String?

    private init() {
        do {
            catalog = try Self.loadCatalog()
            loadError = nil
        } catch {
            catalog = GameCatalog(schemaVersion: 1, sharks: [], vocabulary: [], expansions: nil)
            loadError = error.localizedDescription
        }
    }

    static func loadCatalog(bundle: Bundle = .main) throws -> GameCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw ContentError.missingCatalog
        }
        let data = try Data(contentsOf: url)
        let decodedCatalog = try JSONDecoder().decode(GameCatalog.self, from: data)
        let expansions = Dictionary(uniqueKeysWithValues: (decodedCatalog.expansions ?? []).map { ($0.sharkID, $0) })
        let catalog = GameCatalog(
            schemaVersion: decodedCatalog.schemaVersion,
            sharks: decodedCatalog.sharks.map { $0.expanded(with: expansions[$0.id]) },
            vocabulary: decodedCatalog.vocabulary,
            expansions: decodedCatalog.expansions
        )
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: GameCatalog) throws {
        guard catalog.schemaVersion == 1 else { throw ContentError.invalidCatalog("unsupported schema") }
        guard catalog.sharks.count == 20 else { throw ContentError.invalidCatalog("expected exactly 20 sharks") }
        // Each finished mission must leave another shark to visit until every page is collected.
        let unlockOrder = catalog.sharks.map(\.unlockAt).sorted()
        guard unlockOrder.enumerated().allSatisfy({ $0.element <= $0.offset }) else { throw ContentError.invalidCatalog("a shark can never be unlocked") }
        guard Set(catalog.sharks.map(\.id)).count == catalog.sharks.count else { throw ContentError.invalidCatalog("duplicate shark IDs") }
        guard Set(catalog.vocabulary.map(\.id)).count == catalog.vocabulary.count else { throw ContentError.invalidCatalog("duplicate word IDs") }
        let wordIDs = Set(catalog.vocabulary.map(\.id))

        for shark in catalog.sharks {
            guard shark.topics.count >= 7 else { throw ContentError.invalidCatalog("\(shark.id) must have at least seven topics") }
            guard shark.questions.count == 3 else { throw ContentError.invalidCatalog("\(shark.id) must have exactly three questions") }
            guard shark.traits.count >= 2 else { throw ContentError.invalidCatalog("\(shark.id) needs at least two Passport traits") }
            guard Set(shark.topics.map(\.id)).count == shark.topics.count else { throw ContentError.invalidCatalog("duplicate topic IDs for \(shark.id)") }
            guard shark.traits.allSatisfy({ shark.topics.map(\.id).contains($0.unlockTopicID) }) else {
                throw ContentError.invalidCatalog("Passport trait unlock topic missing for \(shark.id)")
            }
            guard !shark.imageAsset.isEmpty, !shark.imageSourceURL.isEmpty else { throw ContentError.invalidCatalog("missing species image for \(shark.id)") }
            guard shark.vocabularyIDs.count >= 2, shark.vocabularyIDs.count <= 3 else { throw ContentError.invalidCatalog("\(shark.id) must introduce two or three words") }
            guard Set(shark.vocabularyIDs).isSubset(of: wordIDs) else { throw ContentError.invalidCatalog("unknown vocabulary for \(shark.id)") }
            guard !shark.sourceURLs.isEmpty else { throw ContentError.invalidCatalog("missing science source for \(shark.id)") }
            guard !shark.discover.earlyReader.isEmpty, !shark.discover.story.isEmpty else { throw ContentError.invalidCatalog("missing Discover narration") }
            for question in shark.questions {
                guard question.choices.count == 3 else { throw ContentError.invalidCatalog("question \(question.id) needs three choices") }
                guard question.choices.filter({ $0.id == question.correctID }).count == 1 else { throw ContentError.invalidCatalog("question \(question.id) needs one correct choice") }
            }
        }
    }
}
