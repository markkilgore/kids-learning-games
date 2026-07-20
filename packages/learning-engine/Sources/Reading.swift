import Foundation

public enum ReadingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case earlyReader
    case story

    public var id: String { rawValue }
    public var title: String { self == .earlyReader ? "Early Reader" : "Story Mode" }
}

public struct WordToken: Identifiable, Equatable, Sendable {
    public let id: Int
    public let text: String
    public let range: NSRange

    public init(id: Int, text: String, range: NSRange) {
        self.id = id
        self.text = text
        self.range = range
    }
}

public extension String {
    var wordTokens: [WordToken] {
        var result: [WordToken] = []
        enumerateSubstrings(in: startIndex..<endIndex, options: .byWords) { substring, range, _, _ in
            guard let substring else { return }
            result.append(WordToken(id: result.count, text: substring, range: NSRange(range, in: self)))
        }
        return result
    }
}
