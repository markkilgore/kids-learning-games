import LearningUI
import Narration
import SwiftUI

struct CatSettingsView: View {
    @Environment(CatGameStore.self) private var game
    @Environment(SoundSettings.self) private var sound
    @Environment(\.kidTheme) private var theme
    @State private var confirmingReset = false
    @AppStorage(CatActivityView.readsStoryFirstKey) private var readsStoryFirst = false

    var body: some View {
        @Bindable var sound = sound
        VStack(spacing: 18) {
            KidTopBar("Parent Settings", back: KidBackButton("Done", systemImage: "checkmark") { game.showHome() })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Sound", systemImage: "speaker.wave.2.fill") {
                        Toggle("Read stories and questions aloud", isOn: $sound.voiceEnabled)
                        Toggle("Sound effects", isOn: $sound.effectsEnabled)
                        Toggle("Read each story page aloud as it opens", isOn: $readsStoryFirst)
                        Text("When this is off, Kate reads the page herself first. She can tap a word to hear it, or “Read it to me” for the whole page.")
                            .foregroundStyle(theme.mutedInk)
                        Text("Narration is recorded and bundled with the app; nothing is sent over the internet.")
                            .foregroundStyle(theme.mutedInk)
                    }
                    section("Learning in this app", systemImage: "sparkles") {
                        Text(CatAppConfiguration.value.enabledSkills.map(\.displayName).joined(separator: " • "))
                        Text("After each story page Kate hears one of its sentences and finds it among three.")
                        Text("Every puzzle has a picture Kate can tap to count. Wrong answers get an encouraging hint and another try.")
                        Text("Each solved puzzle adds a friendship heart and reveals more of that cat’s story.")
                    }
                    CatProgressSection()
                    section("Saved on this iPad", systemImage: "ipad") {
                        Text("\(game.totalFriendship) friendship hearts • \(game.progress.completedActivities) puzzles solved • \(game.progress.journaledCatIDs.count) journal pages")
                        Button("Start over", systemImage: "arrow.counterclockwise", role: .destructive) { confirmingReset = true }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .confirmationDialog("Erase all hearts, story pages, rewards, and practice records on this iPad?", isPresented: $confirmingReset, titleVisibility: .visible) {
                                Button("Erase progress", role: .destructive) { game.resetProgress() }
                            }
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .foregroundStyle(theme.ink)
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
