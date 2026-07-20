import Foundation

public enum ProgressStoreError: Error, Equatable {
    case invalidNamespace
}

public struct PersistenceScope: Sendable, Equatable {
    public let namespace: String

    public init(namespace: String) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard !namespace.isEmpty, namespace.unicodeScalars.allSatisfy(allowed.contains) else {
            throw ProgressStoreError.invalidNamespace
        }
        self.namespace = namespace
    }

    public func directoryURL(baseDirectory: URL? = nil) throws -> URL {
        let base = try baseDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent(namespace, isDirectory: true)
    }

    public func fileURL(named name: String, baseDirectory: URL? = nil) throws -> URL {
        try directoryURL(baseDirectory: baseDirectory).appendingPathComponent(name, isDirectory: false)
    }
}

@MainActor
public final class NamespacedProgressStore<State: Codable> {
    public let scope: PersistenceScope
    private let fileName: String
    private let baseDirectory: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(namespace: String, fileName: String = "progress.json", baseDirectory: URL? = nil) throws {
        scope = try PersistenceScope(namespace: namespace)
        self.fileName = fileName
        self.baseDirectory = baseDirectory
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public var fileURL: URL { get throws { try scope.fileURL(named: fileName, baseDirectory: baseDirectory) } }

    public var exists: Bool { (try? FileManager.default.fileExists(atPath: fileURL.path)) ?? false }

    public func load(default defaultValue: @autoclosure () -> State) throws -> State {
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return defaultValue() }
        return try decoder.decode(State.self, from: Data(contentsOf: url))
    }

    public func save(_ value: State) throws {
        let url = try fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    public func reset() throws {
        let url = try fileURL
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
