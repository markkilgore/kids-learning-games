import SpriteKit
import SwiftUI
import LearningUI
import Narration

/// One full-screen journey: hear the mission, play it, answer the picture questions, collect the reward.
struct MissionFlowView: View {
    enum Phase: Equatable { case intro, play, complete, questions, reward }

    let shark: SharkDefinition
    let onClose: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var phase = Phase.intro
    @State private var progress = 0
    @State private var counterPop = false
    @State private var confirmingLeave = false
    @State private var reward: MissionReward?
    @State private var celebration = 0
    @State private var scene: MissionScene

    init(shark: SharkDefinition, onClose: @escaping () -> Void) {
        self.shark = shark
        self.onClose = onClose
        _scene = State(initialValue: MissionScene(mission: shark.mission, size: CGSize(width: 1100, height: 620)))
    }

    var body: some View {
        ZStack {
            OceanBackdrop()
            VStack(spacing: 14) {
                KidTopBar(title, back: phase == .reward ? nil : KidBackButton("Stop", systemImage: "xmark") { leave() }) {
                    if phase == .play || phase == .intro {
                        HStack(spacing: 12) {
                            Text("\(progress) of \(shark.mission.targetCount)")
                                .font(.kidTitle)
                                .scaleEffect(counterPop ? 1.3 : 1)
                            ProgressView(value: Double(progress), total: Double(shark.mission.targetCount))
                                .tint(.yellow)
                                .frame(width: 220)
                                .scaleEffect(y: 2.6)
                        }
                    }
                }

                Group {
                    switch phase {
                    case .intro: intro
                    case .play: play
                    case .complete: complete
                    case .questions:
                        QuestionRoundView(shark: shark) { finishQuestions() }
                    case .reward:
                        if let reward { MissionRewardView(shark: shark, reward: reward, onBooks: openBook, onMap: backToMap) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            }
            .padding(24)
            .foregroundStyle(.white)

            CelebrationView(trigger: celebration)

            if confirmingLeave { leaveCard }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: phase)
        .environment(\.kidTheme, .shark)
        .onAppear {
            scene.onProgress = { value in Task { @MainActor in hit(value) } }
            scene.onMiss = { Task { @MainActor in feedback.play(.tap) } }
        }
    }

    private var title: String {
        switch phase {
        case .intro, .play, .complete: shark.mission.title
        case .questions: "Picture questions"
        case .reward: "You did it!"
        }
    }

    private var intro: some View {
        VStack(spacing: 12) {
            SpeciesImageView(shark: shark, contentMode: .fit)
                .frame(maxWidth: 360, maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
            ReadAlongView(sentences: shark.mission.instructions.sentences(for: game.readingMode), finishTitle: "Start!") {
                phase = .play
            }
            .frame(maxWidth: 900)
        }
    }

    private var play: some View {
        SpriteView(scene: scene)
            .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 2))
            .overlay(alignment: .top) {
                Text(missionPrompt)
                    .font(.kidHeadline)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding()
            }
    }

    private var complete: some View {
        VStack(spacing: 22) {
            Text("🌟")
                .font(.system(size: 120))
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            Text(shark.mission.completion)
                .font(.kidDisplay)
                .multilineTextAlignment(.center)
            Button { phase = .questions } label: {
                Label("Answer \(shark.questions.count) picture questions", systemImage: "arrow.right")
            }
            .buttonStyle(KidButtonStyle(tint: theme.success))
            .accessibilityIdentifier("start-questions")
        }
        .padding(30)
        .frame(maxWidth: 820)
        .kidCard(radius: KidTheme.Radius.large)
    }

    private var leaveCard: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("🦈").font(.system(size: 80))
                Text("Stop this mission?").font(.kidDisplay)
                HStack(spacing: 18) {
                    Button { confirmingLeave = false } label: { Label("Keep playing", systemImage: "play.fill") }
                        .buttonStyle(KidButtonStyle(tint: theme.success))
                    Button { backToEncounter() } label: { Label("Stop", systemImage: "xmark") }
                        .buttonStyle(KidButtonStyle(.soft))
                        .accessibilityIdentifier("confirm-stop")
                }
            }
            .padding(36)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous))
            .shadow(radius: 24)
            .foregroundStyle(.white)
        }
        .transition(.opacity)
    }

    private func hit(_ value: Int) {
        progress = value
        feedback.play(.pop)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { counterPop = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) { counterPop = false }
        guard value >= shark.mission.targetCount else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            phase = .complete
            feedback.play(.correct)
            // Let the chime ring before the voice comes in.
            narration.play(shark.mission.completion, after: 0.6)
        }
    }

    private func leave() {
        if phase == .play || phase == .questions {
            narration.play(SharkLine.leave.text)
            withAnimation { confirmingLeave = true }
        } else {
            backToEncounter()
        }
    }

    private func finishQuestions() {
        reward = game.completeMission(for: shark)
        phase = .reward
        feedback.play(.celebrate)
        celebration += 1
        // The fanfare is two seconds long; the voice waits for most of it.
        narration.play(SharkLine.pageEarned.text, after: 1.5)
    }

    private func backToEncounter() {
        narration.stop()
        onClose()
    }

    private func openBook() {
        narration.stop()
        onClose()
        game.showBooks(openingPageFor: shark.id)
    }

    private func backToMap() {
        narration.stop()
        onClose()
        game.showMap()
    }

    private var missionPrompt: String {
        switch shark.mission.kind {
        case "ambushApproach": "Spot the dark fish near the bright surface"
        case "filterFeed": "Tap the plankton sparkle"
        case "electrosense": "Tap the electric clue"
        case "suctionForage": "Tap the crab"
        case "camouflageFind": "Tap the hidden shell"
        case "tailStrike": "Tap the schooling fish"
        case "scentTrack": "Tap the scent trail"
        case "tidalWalk": "Tap the next rock"
        case "jawStrike": "Tap the deep-sea fish"
        case "energyTrail": "Tap the snowy scent clue"
        default: "Tap the clue"
        }
    }
}

/// The payoff after the questions: the new Passport page, new Ocean Words, and any sharks now on the map.
private struct MissionRewardView: View {
    let shark: SharkDefinition
    let reward: MissionReward
    let onBooks: () -> Void
    let onMap: () -> Void
    @Environment(\.kidTheme) private var theme
    @State private var shown = false
    private let catalog = ContentStore.shared.catalog

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 24) {
                SpeciesImageView(shark: shark)
                    .frame(width: 260, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .orange)
                            .offset(x: 16, y: -16)
                            .scaleEffect(shown ? 1 : 0.2)
                    }
                    .rotationEffect(.degrees(shown ? -3 : -14))
                    .scaleEffect(shown ? 1 : 0.6)

                VStack(alignment: .leading, spacing: 12) {
                    Text(reward.isNewPage ? "New Passport page!" : "Passport page")
                        .font(.kidLabel)
                        .textCase(.uppercase)
                        .foregroundStyle(.yellow)
                    Text(shark.name).font(.kidDisplay)

                    let words = catalog.vocabulary.filter { shark.vocabularyIDs.contains($0.id) }
                    HStack(spacing: 10) {
                        ForEach(words) { word in
                            Label { Text(word.word) } icon: { Text(word.symbol) }
                                .font(.kidHeadline)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                                .background(.cyan.opacity(0.3), in: Capsule())
                        }
                    }
                    Text(reward.newWordIDs.isEmpty ? "Your Ocean Words" : "\(reward.newWordIDs.count) new Ocean \(reward.newWordIDs.count == 1 ? "Word" : "Words")")
                        .font(.kidLabel)
                        .foregroundStyle(theme.mutedInk)
                }
                Spacer(minLength: 0)
            }

            let unlocked = catalog.sharks.filter { reward.unlockedSharkIDs.contains($0.id) }
            if !unlocked.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "lock.open.fill").font(.title).foregroundStyle(.yellow)
                    Text(unlocked.count == 1 ? "A new shark is on your map:" : "New sharks are on your map:")
                        .font(.kidHeadline)
                    ForEach(unlocked) { newShark in
                        SpeciesImageView(shark: newShark)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .kidCard(.quiet)
            }

            HStack(spacing: 18) {
                Button(action: onBooks) { Label("Open Shark Book", systemImage: "book.fill") }
                    .buttonStyle(KidButtonStyle(tint: theme.success))
                    .accessibilityIdentifier("open-shark-book")
                Button(action: onMap) { Label("Ocean Map", systemImage: "map.fill") }
                    .buttonStyle(KidButtonStyle(.soft))
            }
        }
        .padding(30)
        .frame(maxWidth: 900)
        .kidCard(radius: KidTheme.Radius.large)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { shown = true }
        }
    }
}
