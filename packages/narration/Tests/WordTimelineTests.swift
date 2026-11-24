import XCTest
import LearningEngine
@testable import Narration

final class WordTimelineTests: XCTestCase {
    func testEachPlainWordKeepsItsRecordedTiming() {
        let timeline = WordTimeline(sentence: "Sharks swim fast.", timedWords: [
            TimedWord(text: "Sharks", start: 0, end: 0.4),
            TimedWord(text: "swim", start: 0.5, end: 0.8),
            TimedWord(text: "fast.", start: 0.9, end: 1.3)
        ])
        XCTAssertEqual(timeline.spans.map(\.start), [0, 0.5, 0.9])
        XCTAssertEqual(timeline.spans.map(\.end), [0.4, 0.8, 1.3])
        XCTAssertEqual(timeline.index(at: 0.6), 1)
        XCTAssertNil(timeline.index(at: -1))
    }

    func testHyphenatedChunkIsSharedBetweenItsWords() {
        // The reader shows "Ta" and "da" separately, but the recording times "Ta-da!" as one chunk.
        let sentence = "Ta-da! Mittens jumped."
        XCTAssertEqual(sentence.wordTokens.map(\.text), ["Ta", "da", "Mittens", "jumped"])
        let timeline = WordTimeline(sentence: sentence, timedWords: [
            TimedWord(text: "Ta-da!", start: 0, end: 0.6),
            TimedWord(text: "Mittens", start: 0.8, end: 1.2),
            TimedWord(text: "jumped.", start: 1.3, end: 1.8)
        ])
        XCTAssertEqual(timeline.spans.count, 4)
        XCTAssertEqual(timeline.spans[0].start, 0)
        XCTAssertEqual(timeline.spans[0].end, timeline.spans[1].start, accuracy: 0.0001)
        XCTAssertEqual(timeline.spans[1].end, 0.6)
        XCTAssertEqual(timeline.spans[2].start, 0.8, "words after the hyphenated chunk must not shift")
        XCTAssertEqual(timeline.spans[3].end, 1.8)
    }

    func testMismatchedTimingsStillCoverEveryWord() {
        let timeline = WordTimeline(sentence: "One two three four", timedWords: [
            TimedWord(text: "One", start: 0, end: 1),
            TimedWord(text: "two", start: 1, end: 2)
        ])
        XCTAssertEqual(timeline.spans.count, 4)
        XCTAssertEqual(timeline.spans.last?.end, 2)
    }

    func testMissingManifestHasNoClips() {
        let manifest = AudioManifest(bundle: Bundle(for: Self.self), resourceName: "does-not-exist")
        XCTAssertTrue(manifest.isEmpty)
        XCTAssertNil(manifest.clipURL(for: "Hello"))
    }
}
