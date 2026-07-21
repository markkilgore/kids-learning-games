import LearningEngine
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
            CatHomeHeader()

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

private struct CatHomeHeader: View {
    @Environment(CatGameStore.self) private var game

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedHeader.frame(minWidth: 1_120)
            compactHeader
        }
    }

    private var expandedHeader: some View {
        HStack {
            title
            Spacer()
            friendshipBadge(showsLabel: true)
            journalButton(showsLabel: true)
            ParentGateButton { game.showSettings() }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(CatAppConfiguration.value.identity.childFacingName)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "#5B376E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Spacer(minLength: 8)
                friendshipBadge(showsLabel: false)
                journalButton(showsLabel: false)
                ParentGateButton { game.showSettings() }
            }
            Text("Make friends by solving playful math puzzles")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(CatAppConfiguration.value.identity.childFacingName)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: "#5B376E"))
            Text("Make friends by solving playful math puzzles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func friendshipBadge(showsLabel: Bool) -> some View {
        Group {
            if showsLabel {
                Label("\(game.totalFriendship) hearts", systemImage: "heart.fill")
            } else {
                Label("\(game.totalFriendship)", systemImage: "heart.fill")
                    .accessibilityLabel("\(game.totalFriendship) friendship hearts")
            }
        }
        .font(.title3.bold())
        .foregroundStyle(.pink)
        .padding(showsLabel ? 16 : 12)
        .background(.white.opacity(0.82), in: Capsule())
    }

    private func journalButton(showsLabel: Bool) -> some View {
        Button {
            game.showJournal()
        } label: {
            if showsLabel {
                Label("Cat Journal", systemImage: "book.closed.fill")
            } else {
                Image(systemName: "book.closed.fill")
                    .frame(width: 52, height: 52)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "#A855F7"))
        .controlSize(.large)
        .accessibilityLabel("Cat Journal")
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
                    Text("\(cat.revealedStory(for: friendship).count) of \(cat.backstory.count) story pages")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "#5B376E"))
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
    @State private var revealedBeat: CatStoryBeat?
    @State private var selectedReward: CatRewardAction?
    @State private var rewardMotion = false

    init(cat: CatDefinition) {
        self.cat = cat
        _challenge = State(initialValue: MathChallengeFactory.challenge(for: cat, friendship: 0))
    }

    var body: some View {
        VStack(spacing: 22) {
            CatActivityHeader(cat: cat, skill: challenge.skill) {
                narration.stop()
                game.showHome()
            }

            let currentStory = cat.storyBeat(for: game.friendship(for: cat))
            HStack(spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.title)
                    .foregroundStyle(Color(hex: cat.color))
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentStory.title).font(.headline.bold())
                    Text(currentStory.story).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hear \(cat.name)’s story", systemImage: "speaker.wave.2.fill") {
                    narration.play(currentStory.story)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(16)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))

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
                if correct {
                    CatRewardMoment(
                        cat: cat,
                        feedback: feedback,
                        story: revealedBeat,
                        selectedReward: selectedReward,
                        rewardMotion: rewardMotion,
                        onReward: chooseReward,
                        onContinue: {
                            narration.stop()
                            game.showHome()
                        }
                    )
                } else {
                    HStack(spacing: 14) {
                        Text("🐾").font(.largeTitle)
                        Text(feedback).font(.title2.bold())
                        Spacer()
                    }
                    .padding(20).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
                }
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
        if correct {
            game.completeActivity(for: cat)
            revealedBeat = cat.storyBeat(for: game.friendship(for: cat))
        }
    }

    private func chooseReward(_ reward: CatRewardAction) {
        guard selectedReward == nil else { return }
        selectedReward = reward
        game.record(reward, for: cat)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.5)) { rewardMotion = true }
        narration.play(reward.celebration(for: cat)) {
            if let revealedBeat { narration.play(revealedBeat.story) }
        }
    }
}

private struct CatRewardMoment: View {
    let cat: CatDefinition
    let feedback: String
    let story: CatStoryBeat?
    let selectedReward: CatRewardAction?
    let rewardMotion: Bool
    let onReward: (CatRewardAction) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                ZStack {
                    Text(selectedReward == .meal ? "🥣" : selectedReward == .treat ? "🐟" : cat.trickSymbol)
                        .font(.system(size: 44))
                        .opacity(selectedReward == nil ? 0 : 1)
                        .offset(x: selectedReward == .treat && rewardMotion ? 44 : 0)
                    Text(cat.symbol)
                        .font(.system(size: 72))
                        .scaleEffect(selectedReward == .meal && rewardMotion ? 1.14 : 1)
                        .rotationEffect(.degrees(selectedReward == .trick && rewardMotion ? 16 : 0))
                        .offset(y: selectedReward == .trick && rewardMotion ? -24 : 0)
                }
                .frame(width: 126, height: 96)
                VStack(alignment: .leading, spacing: 4) {
                    Text(feedback).font(.title2.bold())
                    Text(selectedReward.map { $0.celebration(for: cat) } ?? "Choose a way to celebrate with \(cat.name).")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if selectedReward == nil {
                HStack(spacing: 14) {
                    ForEach(CatRewardAction.allCases) { reward in
                        Button(reward.title, systemImage: reward.symbol) { onReward(reward) }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: cat.color))
                            .controlSize(.large)
                    }
                }
            } else if let story {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "book.pages.fill").font(.title).foregroundStyle(Color(hex: cat.color))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New story page: \(story.title)").font(.headline.bold())
                        Text(story.story).font(.headline)
                    }
                    Spacer()
                    Button("Back to the cats", systemImage: "pawprint.fill", action: onContinue)
                        .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                }
                .padding(14)
                .background(Color(hex: cat.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(18)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct CatActivityHeader: View {
    let cat: CatDefinition
    let skill: EducationalSkill
    let onBack: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedHeader.frame(minWidth: 1_020)
            compactHeader
        }
    }

    private var expandedHeader: some View {
        HStack {
            backButton
            Text("\(cat.symbol) Math time with \(cat.name)")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(Color(hex: "#5B376E"))
            Spacer()
            Label(skill.displayName, systemImage: "sparkles")
                .font(.title3.bold())
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 12) {
            backButton
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cat.symbol) Math time with \(cat.name)")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Color(hex: "#5B376E"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Label(skill.displayName, systemImage: "sparkles")
                    .font(.subheadline.bold())
            }
            Spacer(minLength: 0)
        }
    }

    private var backButton: some View {
        Button("Back", systemImage: "chevron.left", action: onBack)
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#A855F7"))
            .controlSize(.large)
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 2), spacing: 18) {
                    ForEach(CatContent.cats) { cat in
                        let met = game.progress.journaledCatIDs.contains(cat.id)
                        CatJournalCard(cat: cat, met: met)
                    }
                }
            }
        }.padding(28)
    }
}

private struct CatJournalCard: View {
    let cat: CatDefinition
    let met: Bool
    @Environment(CatGameStore.self) private var game

    var body: some View {
        let friendship = game.friendship(for: cat)
        let stories = cat.revealedStory(for: friendship)
        HStack(alignment: .top, spacing: 16) {
            Text(met ? cat.symbol : "❔").font(.system(size: 62))
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(met ? cat.name : "New friend").font(.title3.bold())
                    Spacer()
                    if met {
                        Label("\(friendship)", systemImage: "heart.fill").foregroundStyle(.pink).font(.headline)
                    }
                }
                if met {
                    Text("Loves \(cat.favoriteThing).")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    ForEach(stories) { story in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.title).font(.caption.bold()).foregroundStyle(Color(hex: cat.color))
                            Text(story.story).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if stories.count < cat.backstory.count {
                        Label("Solve again to discover the next page", systemImage: "lock.fill")
                            .font(.caption.bold()).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        rewardCount(.treat, label: "treats", symbol: "fish.fill")
                        rewardCount(.meal, label: "meals", symbol: "takeoutbag.and.cup.and.straw.fill")
                        rewardCount(.trick, label: "tricks", symbol: "sparkles")
                    }
                } else {
                    Text("Solve math together to begin this cat’s story.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: cat.color).opacity(met ? 0.45 : 0.12), lineWidth: 2))
    }

    private func rewardCount(_ reward: CatRewardAction, label: String, symbol: String) -> some View {
        Label("\(game.rewardCount(reward, for: cat)) \(label)", systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(Color(hex: "#5B376E"))
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
                    Text("Stories and prompts use bundled narration when available. Every puzzle includes a visual counting or pattern hint.")
                    Text("Friendship reveals each cat’s story. Treats, meals, tricks, and progress stay on this iPad.")
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
