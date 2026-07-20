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

    private init() {
        do {
            catalog = try Self.loadCatalog()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func loadCatalog(bundle: Bundle = .main) throws -> GameCatalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw ContentError.missingCatalog
        }
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(GameCatalog.self, from: data)
        try validate(catalog)
        return catalog
    }

    static func validate(_ catalog: GameCatalog) throws {
        guard catalog.schemaVersion == 1 else { throw ContentError.invalidCatalog("unsupported schema") }
        guard catalog.sharks.count == 10 else { throw ContentError.invalidCatalog("expected exactly 10 sharks") }
        guard Set(catalog.sharks.map(\.id)).count == catalog.sharks.count else { throw ContentError.invalidCatalog("duplicate shark IDs") }
        guard Set(catalog.vocabulary.map(\.id)).count == catalog.vocabulary.count else { throw ContentError.invalidCatalog("duplicate word IDs") }
        let wordIDs = Set(catalog.vocabulary.map(\.id))

        for shark in catalog.sharks {
            guard shark.topics.count == 5 else { throw ContentError.invalidCatalog("\(shark.id) must have five topics") }
            guard shark.questions.count == 3 else { throw ContentError.invalidCatalog("\(shark.id) must have three questions") }
            guard Set(shark.topics.map(\.id)).count == 5 else { throw ContentError.invalidCatalog("duplicate topic IDs for \(shark.id)") }
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
