import SwiftUI
import LearningEngine

struct ParentSettingsView: View {
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Text("Parent Settings")
                    .font(.largeTitle.weight(.black))
                Spacer()
                Button("Done", systemImage: "checkmark.circle.fill") { game.showMap() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(minHeight: 58)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Reading level", systemImage: "text.book.closed.fill")
                    .font(.title2.bold())
                Picker("Reading level", selection: Binding(get: { game.readingMode }, set: { game.setReadingMode($0) })) {
                    ForEach(ReadingMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 600)
                Text(game.readingMode == .earlyReader
                     ? "Short, concrete sentences for independent play."
                     : "Richer sentences for playing with an adult.")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 12) {
                Label("Learning design", systemImage: "sparkles")
                    .font(.title2.bold())
                Text("ST and SP words are worked naturally into the narration. Pronunciation recording and scoring are intentionally not part of this first version.")
                Text("All incorrect-answer feedback is encouraging and gives Henry another visual clue.")
            }
            .font(.title3)
            .padding(24)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 8) {
                Label("Saved on this iPad", systemImage: "ipad")
                    .font(.title2.bold())
                Text("\(game.completedCount) shark pages • \(game.collectedWords.count) Ocean Words • \(game.completedTopics.count) topics explored")
            }
            .padding(24)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))

            DisclosureGroup("Species image credits") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ContentStore.shared.catalog.sharks) { shark in
                            if let url = URL(string: shark.imageSourceURL) {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shark.name).font(.headline)
                                        Text("\(shark.imageAuthor) • \(shark.imageLicense)")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.72))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                }
                .frame(maxHeight: 220)
            }
            .font(.title3.bold())
            .padding(24)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22))

            Spacer()
        }
        .padding(34)
        .foregroundStyle(.white)
    }
}
