import Foundation

public struct AudioManifestEntry: Codable, Sendable {
    let file: String
    let words: [TimedWord]
}

public struct TimedWord: Codable, Sendable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
}

final class AudioManifest: @unchecked Sendable {
    private let entries: [String: AudioManifestEntry]

    init(bundle: Bundle, resourceName: String?) {
        guard let resourceName,
              let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: AudioManifestEntry].self, from: data) else {
            entries = [:]
            return
        }
        entries = decoded
    }

    func entry(for text: String) -> AudioManifestEntry? { entries[text] }
}
