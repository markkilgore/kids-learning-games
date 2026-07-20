import LearningEngine
import SwiftData

@Model
final class PlayerProgressRecord {
    var completedSharksCSV: String
    var collectedWordsCSV: String
    var completedTopicsCSV: String
    var currentSharkID: String?
    var readingModeRaw: String

    init(completedSharksCSV: String = "", collectedWordsCSV: String = "", completedTopicsCSV: String = "", currentSharkID: String? = nil, readingModeRaw: String = ReadingMode.earlyReader.rawValue) {
        self.completedSharksCSV = completedSharksCSV
        self.collectedWordsCSV = collectedWordsCSV
        self.completedTopicsCSV = completedTopicsCSV
        self.currentSharkID = currentSharkID
        self.readingModeRaw = readingModeRaw
    }
}

@MainActor
enum LegacySharkProgressMigration {
    static func load(container suppliedContainer: ModelContainer? = nil) -> SharkProgress? {
        let container: ModelContainer
        if let suppliedContainer { container = suppliedContainer }
        else if let defaultContainer = try? ModelContainer(for: PlayerProgressRecord.self) { container = defaultContainer }
        else { return nil }

        let descriptor = FetchDescriptor<PlayerProgressRecord>()
        guard let record = try? container.mainContext.fetch(descriptor).first else { return nil }
        return progress(from: record)
    }

    static func progress(from record: PlayerProgressRecord) -> SharkProgress {
        SharkProgress(
            completedSharks: set(from: record.completedSharksCSV),
            collectedWords: set(from: record.collectedWordsCSV),
            completedTopics: set(from: record.completedTopicsCSV),
            currentSharkID: record.currentSharkID,
            readingMode: ReadingMode(rawValue: record.readingModeRaw) ?? .earlyReader
        )
    }

    private static func set(from csv: String) -> Set<String> {
        Set(csv.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
}
