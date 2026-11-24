import SwiftUI
import LearningEngine
import LearningUI
import Narration

struct ParentSettingsView: View {
    @Environment(GameStore.self) private var game
    @Environment(SoundSettings.self) private var sound
    @Environment(\.kidTheme) private var theme

    var body: some View {
        @Bindable var sound = sound
        VStack(spacing: 18) {
            KidTopBar("Parent Settings", back: KidBackButton("Done", systemImage: "checkmark") { game.showMap() })

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Reading level", systemImage: "text.book.closed.fill") {
                        KidTabs(selection: Binding(get: { game.readingMode }, set: { game.setReadingMode($0) }), items: ReadingMode.allCases.map {
                            .init($0, $0.title, systemImage: $0 == .earlyReader ? "textformat.size.smaller" : "textformat.size.larger")
                        })
                        .frame(maxWidth: 560)
                        Text(game.readingMode == .earlyReader
                             ? "Short, concrete sentences for independent play."
                             : "Richer sentences for playing with an adult.")
                            .foregroundStyle(theme.mutedInk)
                    }

                    section("Sound", systemImage: "speaker.wave.2.fill") {
                        Toggle("Read stories and questions aloud", isOn: $sound.voiceEnabled)
                        Toggle("Sound effects", isOn: $sound.effectsEnabled)
                        Text("Narration is recorded and bundled with the app; nothing is sent over the internet.")
                            .foregroundStyle(theme.mutedInk)
                    }

                    section("Learning design", systemImage: "sparkles") {
                        Text("ST and SP words are worked naturally into the narration. Pronunciation recording and scoring are intentionally not part of this version.")
                        Text("All incorrect-answer feedback is encouraging and gives Henry another visual clue.")
                    }

                    SharkProgressSection()

                    section("Saved on this iPad", systemImage: "ipad") {
                        Text("\(game.completedCount) shark pages • \(game.collectedWords.count) Ocean Words • \(game.completedTopics.count) topics explored")
                    }

                    section("Species image credits", systemImage: "photo.fill") {
                        ForEach(ContentStore.shared.catalog.sharks) { shark in
                            if let url = URL(string: shark.imageSourceURL) {
                                Link(destination: url) {
                                    Text("\(shark.name) — \(shark.imageAuthor) • \(shark.imageLicense)")
                                        .multilineTextAlignment(.leading)
                                }
                                .tint(.cyan)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .foregroundStyle(.white)
    }

    private func section(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.kidHeadline)
            content()
        }
        .font(.kidBody)
        .tint(theme.primary)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kidCard()
    }
}
