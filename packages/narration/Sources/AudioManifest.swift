import Foundation
import LearningEngine

public struct AudioManifestEntry: Codable, Sendable {
    public let file: String
    public let words: [TimedWord]
}

public struct TimedWord: Codable, Sendable, Equatable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval

    public init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// Maps spoken text to the narration clips bundled with an app.
public final class AudioManifest: @unchecked Sendable {
    private let entries: [String: AudioManifestEntry]
    private let bundle: Bundle

    public init(bundle: Bundle, resourceName: String?) {
        self.bundle = bundle
        guard let resourceName,
              let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: AudioManifestEntry].self, from: data) else {
            entries = [:]
            return
        }
        entries = decoded
    }

    public var isEmpty: Bool { entries.isEmpty }

    public func entry(for text: String) -> AudioManifestEntry? { entries[text] }

    /// The clip for `text`, when both its manifest entry and its audio file are in the bundle.
    public func clipURL(for text: String) -> URL? {
        guard let entry = entries[text] else { return nil }
        let name = entry.file as NSString
        return bundle.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension)
    }
}

/// When each on-screen word is spoken inside a narration clip.
///
/// Clips are timed per whitespace-separated chunk, but the reader shows `String.wordTokens`,
/// which also splits hyphenated chunks such as "Ta-da!". Each chunk's time is shared between
/// the tokens inside it in proportion to where they start.
public struct WordTimeline: Equatable, Sendable {
    public struct Span: Equatable, Sendable {
        public let start: TimeInterval
        public let end: TimeInterval
    }

    public let spans: [Span]

    public init(sentence: String, timedWords: [TimedWord]) {
        let tokens = sentence.wordTokens
        let chunks = Self.chunkRanges(in: sentence)
        guard !tokens.isEmpty, !timedWords.isEmpty else {
            spans = []
            return
        }
        guard chunks.count == timedWords.count else {
            spans = tokens.indices.map { index in
                let timed = timedWords[min(index * timedWords.count / tokens.count, timedWords.count - 1)]
                return Span(start: timed.start, end: timed.end)
            }
            return
        }
        var result: [Span] = []
        for (tokenIndex, token) in tokens.enumerated() {
            guard let chunkIndex = chunks.firstIndex(where: { NSLocationInRange(token.range.location, $0) }) else {
                result.append(result.last ?? Span(start: 0, end: 0))
                continue
            }
            let chunk = chunks[chunkIndex], timed = timedWords[chunkIndex]
            let duration = timed.end - timed.start
            func time(at location: Int) -> TimeInterval {
                timed.start + duration * Double(location - chunk.location) / Double(max(chunk.length, 1))
            }
            let isFirstInChunk = tokenIndex == 0 || !NSLocationInRange(tokens[tokenIndex - 1].range.location, chunk)
            let next = tokenIndex + 1 < tokens.count ? tokens[tokenIndex + 1] : nil
            let nextSharesChunk = next.map { NSLocationInRange($0.range.location, chunk) } ?? false
            result.append(Span(
                start: isFirstInChunk ? timed.start : time(at: token.range.location),
                end: nextSharesChunk ? time(at: next!.range.location) : timed.end
            ))
        }
        spans = result
    }

    public func index(at time: TimeInterval) -> Int? {
        spans.lastIndex { time >= $0.start }
    }

    private static func chunkRanges(in sentence: String) -> [NSRange] {
        let text = sentence as NSString
        var ranges: [NSRange] = []
        var start: Int?
        for index in 0..<text.length {
            let isSpace = CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(text.character(at: index)) ?? " ")
            if isSpace {
                if let begin = start { ranges.append(NSRange(location: begin, length: index - begin)) }
                start = nil
            } else if start == nil {
                start = index
            }
        }
        if let begin = start { ranges.append(NSRange(location: begin, length: text.length - begin)) }
        return ranges
    }
}

/// Fixed interface lines an app speaks, shared with the audio generator through `ui-lines.json`.
public struct SpokenLines: Sendable {
    public let all: [String: String]

    public init(bundle: Bundle = .main, resourceName: String = "ui-lines") {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            all = [:]
            return
        }
        all = decoded
    }

    public subscript(key: String) -> String { all[key] ?? "" }
}
