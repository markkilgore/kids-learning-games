import LearningUI
import Narration
import SwiftUI

struct CatRootView: View {
    @State private var game = CatGameStore()
    @State private var narration = NarrationCoordinator(configuration: CatAppConfiguration.value.narration)

    var body: some View {
        ZStack {
            CatBackdrop(locationID: game.selectedLocationID)
            switch game.destination {
            case .home:
                CatHomeView()
            case .activity(let catID):
                if let cat = CatContent.cats.first(where: { $0.id == catID }) { CatActivityView(cat: cat) }
                else { CatHomeView() }
            case .journal:
                CatJournalView()
            case .settings:
                CatSettingsView()
            }
        }
        .environment(game)
        .environment(narration)
        .task { game.load() }
    }
}

private struct CatBackdrop: View {
    let locationID: String

    var body: some View {
        LinearGradient(
            colors: locationID == "garden"
                ? [Color(hex: "#DDF4D4"), Color(hex: "#BDE0FE"), Color(hex: "#FFF4D6")]
                : [Color(hex: "#FFF4D6"), Color(hex: "#FADADD"), Color(hex: "#E9D5FF")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: locationID == "garden" ? .bottom : .topTrailing) {
            Text(locationID == "garden" ? "🌻  🌿  🌷  🪴  🌼" : "🪟  🛋️  🧶")
                .font(.system(size: 54)).padding(30).opacity(0.5)
        }
        .ignoresSafeArea()
    }
}

private struct CatHomeView: View {
    @Environment(CatGameStore.self) private var game

    private var visibleCats: [CatDefinition] { CatContent.cats.filter { $0.locationID == game.selectedLocationID } }

    var body: some View {
        @Bindable var game = game
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CatAppConfiguration.value.identity.childFacingName)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "#5B376E"))
                    Text("Make friends by solving playful math puzzles")
                        .font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(game.totalFriendship) hearts", systemImage: "heart.fill")
                    .font(.title3.bold()).foregroundStyle(.pink)
                    .padding(16).background(.white.opacity(0.82), in: Capsule())
                Button("Cat Journal", systemImage: "book.closed.fill") { game.showJournal() }
                    .buttonStyle(.borderedProminent).tint(Color(hex: "#A855F7")).controlSize(.large)
                ParentGateButton { game.showSettings() }
            }

            Picker("Place", selection: $game.selectedLocationID) {
                ForEach(CatContent.locations) { location in Label(location.name, systemImage: location.symbol).tag(location.id) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 520)

            HStack(spacing: 22) {
                ForEach(visibleCats) { cat in
                    CatCard(cat: cat, unlocked: game.isUnlocked(cat), friendship: game.friendship(for: cat)) { game.open(cat) }
                }
            }
            .frame(maxHeight: .infinity)

            Text(game.selectedLocationID == "garden" ? "Visit garden friends and grow number patterns." : "Cozy house cats are ready for counting games.")
                .font(.headline).foregroundStyle(Color(hex: "#5B376E")).padding(.bottom, 8)
        }
        .padding(26)
    }
}

private struct CatCard: View {
    let cat: CatDefinition
    let unlocked: Bool
    let friendship: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(unlocked ? cat.symbol : "🔒").font(.system(size: 74))
                Text(cat.name).font(.title2.weight(.black))
                if unlocked {
                    Text(cat.favoriteThing).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Label("\(friendship) friendship", systemImage: "heart.fill").foregroundStyle(.pink).font(.headline)
                } else {
                    Text("Earn \(cat.unlockAt) total hearts").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(18).frame(maxWidth: .infinity, minHeight: 260)
            .background(.white.opacity(unlocked ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color(hex: cat.color).opacity(0.55), lineWidth: 3))
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityLabel(unlocked ? "Play math with \(cat.name)" : "\(cat.name), locked")
    }
}

private struct CatActivityView: View {
    let cat: CatDefinition
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @State private var challenge: MathChallenge
    @State private var feedback: String?
    @State private var correct = false

    init(cat: CatDefinition) {
        self.cat = cat
        _challenge = State(initialValue: MathChallengeFactory.challenge(for: cat, friendship: 0))
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button("Back", systemImage: "chevron.left") { narration.stop(); game.showHome() }
                    .buttonStyle(.borderedProminent).tint(Color(hex: "#A855F7")).controlSize(.large)
                Text("\(cat.symbol) Math time with \(cat.name)").font(.largeTitle.weight(.black)).foregroundStyle(Color(hex: "#5B376E"))
                Spacer()
                Label(challenge.skill.displayName, systemImage: "sparkles").font(.title3.bold())
            }

            VStack(spacing: 18) {
                Text(challenge.prompt).font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                Button("Hear the question", systemImage: "speaker.wave.2.fill") { narration.play(challenge.prompt) }
                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
                Text(challenge.visualHint).font(.system(size: 36)).multilineTextAlignment(.center)
                    .padding(20).frame(maxWidth: .infinity, minHeight: 110)
                    .background(Color(hex: "#FFF9EE"), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityLabel("Visual hint: \(challenge.visualHint)")
            }
            .padding(24).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 28))

            HStack(spacing: 20) {
                ForEach(challenge.choices, id: \.self) { choice in
                    Button("\(choice)") { choose(choice) }
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .buttonStyle(.borderedProminent).tint(Color(hex: cat.color)).controlSize(.large)
                        .disabled(correct)
                }
            }

            if let feedback {
                HStack(spacing: 14) {
                    Text(correct ? "💖" : "🐾").font(.largeTitle)
                    Text(feedback).font(.title2.bold())
                    Spacer()
                    if correct {
                        Button("Back to the cats") { game.showHome() }.buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                    }
                }
                .padding(20).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
            }
            Spacer()
        }
        .padding(28)
        .onAppear {
            challenge = MathChallengeFactory.challenge(for: cat, friendship: game.friendship(for: cat))
            narration.play(challenge.prompt)
        }
        .onDisappear { narration.stop() }
    }

    private func choose(_ choice: Int) {
        correct = choice == challenge.answer
        feedback = correct ? "You did it! \(cat.name)’s friendship grew." : "Good try. Use the picture hint and count once more."
        narration.play(feedback ?? "")
        if correct { game.completeActivity(for: cat) }
    }
}

private struct CatJournalView: View {
    @Environment(CatGameStore.self) private var game

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("House & Garden", systemImage: "chevron.left") { game.showHome() }.buttonStyle(.borderedProminent).tint(Color(hex: "#A855F7")).controlSize(.large)
                Text("Kate’s Cat Journal").font(.largeTitle.weight(.black)).foregroundStyle(Color(hex: "#5B376E"))
                Spacer()
                Text("\(game.progress.journaledCatIDs.count) of \(CatContent.cats.count) friends").font(.title3.bold())
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 5), spacing: 18) {
                    ForEach(CatContent.cats) { cat in
                        let met = game.progress.journaledCatIDs.contains(cat.id)
                        VStack(spacing: 10) {
                            Text(met ? cat.symbol : "❔").font(.system(size: 62))
                            Text(met ? cat.name : "New friend").font(.title3.bold())
                            Text(met ? "Loves \(cat.favoriteThing). You have \(game.friendship(for: cat)) friendship hearts." : "Solve math together to add this page.")
                                .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .padding(16).frame(maxWidth: .infinity, minHeight: 205)
                        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
        }.padding(28)
    }
}

private struct CatSettingsView: View {
    @Environment(CatGameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Parent Settings").font(.largeTitle.weight(.black))
                Spacer()
                Button("Done", systemImage: "checkmark.circle.fill") { game.showHome() }.buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
            }
            GroupBox("Learning in this app") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(CatAppConfiguration.value.enabledSkills.map(\.displayName).joined(separator: " • "))
                    Text("Prompts are narrated. Every puzzle includes a visual counting or pattern hint.")
                    Text("Friendship grows locally on this iPad and unlocks more cats.")
                }.font(.title3).frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            GroupBox("Saved progress") {
                Text("\(game.totalFriendship) friendship hearts • \(game.progress.completedActivities) activities • \(game.progress.journaledCatIDs.count) journal pages")
                    .font(.title3).frame(maxWidth: .infinity, alignment: .leading).padding()
            }
            Spacer()
        }.padding(34).foregroundStyle(Color(hex: "#5B376E"))
    }
}

private struct ParentGateButton: View {
    let action: () -> Void
    @GestureState private var pressing = false

    var body: some View {
        Image(systemName: "gearshape.fill").font(.title2).frame(width: 58, height: 58)
            .background(pressing ? Color.orange.opacity(0.7) : Color.white.opacity(0.8), in: Circle())
            .gesture(LongPressGesture(minimumDuration: 2).updating($pressing) { value, state, _ in state = value }.onEnded { _ in action() })
            .accessibilityLabel("Parent settings. Press and hold.")
    }
}
