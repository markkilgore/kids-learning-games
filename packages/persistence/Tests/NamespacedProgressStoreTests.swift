import XCTest
@testable import LearningPersistence

final class NamespacedProgressStoreTests: XCTestCase {
    private struct Sample: Codable, Equatable { let score: Int }

    @MainActor
    func testNamespacesProduceIndependentFilesAndValues() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let shark = try NamespacedProgressStore<Sample>(namespace: "henry.shark", baseDirectory: base)
        let cat = try NamespacedProgressStore<Sample>(namespace: "kate.cat", baseDirectory: base)
        try shark.save(Sample(score: 7))
        try cat.save(Sample(score: 3))

        XCTAssertNotEqual(try shark.fileURL, try cat.fileURL)
        XCTAssertEqual(try shark.load(default: Sample(score: 0)), Sample(score: 7))
        XCTAssertEqual(try cat.load(default: Sample(score: 0)), Sample(score: 3))
        try shark.reset()
        XCTAssertEqual(try cat.load(default: Sample(score: 0)), Sample(score: 3))
    }

    func testRejectsPathLikeNamespace() {
        XCTAssertThrowsError(try PersistenceScope(namespace: "../shared"))
    }
}
