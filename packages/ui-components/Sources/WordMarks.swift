import SwiftUI

/// How a word in a read-along passage relates to what the child is learning to read.
public enum WordMark: Equatable, Sendable {
    /// A word the child can sound out with the letters taught so far.
    case decodable
    /// A sound-it-out word that uses one of the newest letters.
    case featured
    /// A "heart word": common, not yet decodable, learned by heart.
    case heart
}

private struct WordMarkerKey: EnvironmentKey {
    static let defaultValue: (@Sendable (String) -> WordMark?)? = nil
}

public extension EnvironmentValues {
    /// Classifies words for `ReadAlongView`; nil leaves every word unmarked.
    var wordMarker: (@Sendable (String) -> WordMark?)? {
        get { self[WordMarkerKey.self] }
        set { self[WordMarkerKey.self] = newValue }
    }
}
