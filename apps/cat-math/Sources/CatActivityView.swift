import LearningEngine
import LearningUI
import Narration
import SwiftUI

/// One puzzle with a cat: the cat and its story on the left, the puzzle on the right, then a reward.
struct CatActivityView: View {
    let cat: CatDefinition
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var challenge: MathChallenge
    @State private var wrongChoices: Set<Int> = []
    @State private var correct = false
    @State private var counted = 0
    @State private var revealedBeat: CatStoryBeat?
    @State private var newFriends: [CatDefinition] = []
    @State private var selectedReward: CatRewardAction?
    @State private var rewardMotion = false
    @State private var showReward = false
    @State private var celebration = 0

    init(cat: CatDefinition, friendship: Int) {
        self.cat = cat
        _challenge = State(initialValue: MathChallengeFactory.challenge(for: cat, friendship: friendship))
    }

    var body: some View {
        let friendship = game.friendship(for: cat)
        VStack(spacing: 16) {
            KidTopBar("Math time with \(cat.name)", subtitle: challenge.skill.displayName, back: KidBackButton { goHome() }) {
                Label("\(friendship)", systemImage: "heart.fill")
                    .font(.kidTitle)
                    .foregroundStyle(.pink)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(friendship) hearts with \(cat.name)")
            }

            HStack(alignment: .top, spacing: 18) {
                storyColumn(friendship: friendship)
                    .frame(width: 290)
                puzzleColumn
            }
            .frame(maxHeight: .infinity)
        }
        .padding(24)
        .foregroundStyle(theme.ink)
        .overlay {
            if showReward {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    CatRewardCard(
                        cat: cat,
                        story: revealedBeat,
                        newFriends: newFriends,
                        selectedReward: selectedReward,
                        rewardMotion: rewardMotion,
                        onReward: chooseReward,
                        onNext: nextPuzzle,
                        onHome: goHome
                    )
                    .padding(40)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .overlay { CelebrationView(trigger: celebration) }
        .onAppear { narration.play(challenge.prompt) }
        .onDisappear { narration.stop() }
    }

    private func storyColumn(friendship: Int) -> some View {
        let story = cat.storyBeat(for: correct ? friendship - 1 : friendship)
        return VStack(spacing: 12) {
            ZStack {
                Circle().fill(cat.tint.opacity(0.22)).frame(width: 150, height: 150)
                KidArt(cat.artName, fallback: cat.symbol, size: 100)
                    .scaleEffect(correct ? 1.12 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.45), value: correct)
            }
            StoryDots(revealed: cat.revealedStory(for: friendship).count, total: cat.backstory.count, tint: cat.tint)
            Text(story.title).font(.kidHeadline).multilineTextAlignment(.center)
            Text(story.story)
                .font(.kidBody)
                .foregroundStyle(theme.ink.opacity(0.88))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Button { narration.play(story.story) } label: { Label("Hear the story", systemImage: "book.fill") }
                .buttonStyle(KidButtonStyle(.soft, tint: cat.tint, compact: true))
        }
        .padding(18)
        .frame(maxHeight: .infinity)
        .kidCard(radius: KidTheme.Radius.large)
    }

    private var puzzleColumn: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text(challenge.prompt)
                    .font(.kidTitle)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { narration.play(challenge.prompt) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.title2)
                }
                .buttonStyle(KidButtonStyle(tint: theme.secondary, compact: true))
                .accessibilityLabel("Hear the question")
            }

            MathVisualView(challenge: challenge, counted: $counted) { number in
                feedback.play(.pop)
                narration.play(CatLine.count(number))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
            .accessibilityLabel("Picture hint: \(challenge.visualHint)")

            HStack(spacing: 16) {
                ForEach(challenge.choices, id: \.self) { choice in
                    AnswerTile(state: state(of: choice), tint: cat.tint) { choose(choice) } label: {
                        Text(challenge.label(for: choice))
                            .font(.system(size: 46, weight: .black, design: .rounded))
                    }
                    .accessibilityIdentifier(choice == challenge.answer ? "answer-correct" : "answer-other")
                }
            }

            if !wrongChoices.isEmpty, !correct {
                Label(CatLine.retry.text, systemImage: "pawprint.fill")
                    .font(.kidHeadline)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidCard(radius: KidTheme.Radius.large)
    }

    private func state(of choice: Int) -> AnswerState {
        if correct { return choice == challenge.answer ? .correct : .dimmed }
        return wrongChoices.contains(choice) ? .wrong : .idle
    }

    private func choose(_ choice: Int) {
        guard !correct else { return }
        guard choice == challenge.answer else {
            feedback.play(.wrong)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { _ = wrongChoices.insert(choice) }
            narration.play(CatLine.retry.text)
            return
        }
        correct = true
        feedback.play(.correct)
        celebration += 1
        withAnimation { newFriends = game.completeActivity(for: cat) }
        revealedBeat = cat.storyBeat(for: game.friendship(for: cat))
        narration.play("You did it! \(cat.name)’s friendship grew.")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showReward = true }
        }
    }

    private func chooseReward(_ reward: CatRewardAction) {
        guard selectedReward == nil else { return }
        game.record(reward, for: cat)
        feedback.play(newFriends.isEmpty ? .pop : .unlock)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.5)) {
            selectedReward = reward
            rewardMotion = true
        }
        narration.play(reward.celebration(for: cat)) {
            if !newFriends.isEmpty {
                narration.play(CatLine.newFriend.text)
            } else if let revealedBeat {
                narration.play(revealedBeat.story)
            }
        }
    }

    private func nextPuzzle() {
        narration.stop()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            challenge = MathChallengeFactory.challenge(for: cat, friendship: game.friendship(for: cat))
            wrongChoices = []
            correct = false
            counted = 0
            revealedBeat = nil
            newFriends = []
            selectedReward = nil
            rewardMotion = false
            showReward = false
        }
        narration.play(challenge.prompt)
    }

    private func goHome() {
        narration.stop()
        game.showHome()
    }
}

/// The puzzle's picture. Countable objects can be tapped: each tap numbers the object and says the count.
private struct MathVisualView: View {
    let challenge: MathChallenge
    @Binding var counted: Int
    let onCount: (Int) -> Void
    @Environment(\.kidTheme) private var theme
    @State private var order: [Int: Int] = [:]

    var body: some View {
        // Drawn at one size, then enlarged to use the room a bigger iPad gives it.
        GeometryReader { proxy in
            picture
                .scaleEffect(max(1, min(proxy.size.height / 250, proxy.size.width / 700, 1.8)))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onChange(of: counted) { _, value in
            if value == 0 { order = [:] }
        }
    }

    private var picture: some View {
        Group {
            switch challenge.visual {
            case .count(let total):
                objects(0..<total)
            case .add(let first, let second):
                HStack(spacing: 14) {
                    objects(0..<first)
                    Text("+").font(.system(size: 50, weight: .black, design: .rounded))
                    objects(first..<(first + second))
                }
            case .subtract(let total, let taken):
                objects(0..<total, crossedFrom: total - taken)
            case .pairs(let total):
                HStack(spacing: 18) {
                    ForEach(0..<((total + 1) / 2), id: \.self) { pair in
                        VStack(spacing: 4) {
                            object(pair * 2, crossed: false)
                            if pair * 2 + 1 < total { object(pair * 2 + 1, crossed: false) } else { Color.clear.frame(width: 58, height: 58) }
                        }
                        .padding(6)
                        .background(theme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
                    }
                }
            case .sequence(let numbers):
                HStack(spacing: 16) {
                    ForEach(numbers, id: \.self) { number in sequenceChip("\(number)") }
                    sequenceChip("?").foregroundStyle(theme.secondary)
                }
            }
        }
    }

    private func objects(_ range: Range<Int>, crossedFrom: Int? = nil) -> some View {
        WordFlowLayout(spacing: 6) {
            ForEach(Array(range), id: \.self) { index in
                object(index, crossed: crossedFrom.map { index >= $0 } ?? false)
            }
        }
        .frame(maxWidth: CGFloat(min(range.count, 5)) * 64 + 2)
    }

    private func object(_ index: Int, crossed: Bool) -> some View {
        Button {
            guard !crossed, order[index] == nil else { return }
            counted += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { order[index] = counted }
            onCount(counted)
        } label: {
            Text(challenge.icon)
                .font(.system(size: 42))
                .frame(width: 58, height: 58)
                .opacity(crossed ? 0.3 : 1)
                .scaleEffect(order[index] == nil ? 1 : 1.12)
                .overlay {
                    if crossed {
                        Image(systemName: "xmark").font(.system(size: 34, weight: .black)).foregroundStyle(.red.opacity(0.7))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let number = order[index] {
                        Text("\(number)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(theme.primary, in: Circle())
                            .transition(.scale)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private func sequenceChip(_ text: String) -> some View {
        VStack(spacing: 4) {
            Text(challenge.icon).font(.system(size: 40))
            Text(text)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .frame(minWidth: 84, minHeight: 64)
                .background(theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
        }
    }
}

/// Shown after a correct answer: celebrate with the cat, read the new story page, then keep playing or go home.
private struct CatRewardCard: View {
    let cat: CatDefinition
    let story: CatStoryBeat?
    let newFriends: [CatDefinition]
    let selectedReward: CatRewardAction?
    let rewardMotion: Bool
    let onReward: (CatRewardAction) -> Void
    let onNext: () -> Void
    let onHome: () -> Void
    @Environment(\.kidTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 20) {
                ZStack {
                    Text(selectedReward == .meal ? "🥣" : selectedReward == .treat ? "🐟" : cat.trickSymbol)
                        .font(.system(size: 54))
                        .opacity(selectedReward == nil ? 0 : 1)
                        .offset(x: selectedReward == .trick ? 0 : 70, y: selectedReward == .trick ? -70 : 20)
                    KidArt(cat.artName, fallback: cat.symbol, size: 100)
                        .scaleEffect(selectedReward == .meal && rewardMotion ? 1.14 : 1)
                        .rotationEffect(.degrees(selectedReward == .trick && rewardMotion ? 16 : 0))
                        .offset(x: selectedReward == .treat && rewardMotion ? 16 : 0, y: selectedReward == .trick && rewardMotion ? -24 : 0)
                }
                .frame(width: 190, height: 140)
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(cat.name)’s friendship grew!", systemImage: "heart.fill")
                        .font(.kidDisplay)
                        .foregroundStyle(.pink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(selectedReward.map { $0.celebration(for: cat) } ?? "Choose a way to celebrate with \(cat.name).")
                        .font(.kidHeadline)
                        .foregroundStyle(theme.mutedInk)
                }
                Spacer(minLength: 0)
            }

            if selectedReward == nil {
                HStack(spacing: 16) {
                    ForEach(CatRewardAction.allCases) { reward in
                        Button { onReward(reward) } label: { Label(reward.title, systemImage: reward.symbol) }
                            .buttonStyle(KidButtonStyle(tint: cat.tint))
                            .accessibilityIdentifier("reward-\(reward.rawValue)")
                    }
                }
                .transition(.opacity)
            } else {
                ForEach(newFriends) { friend in
                    HStack(spacing: 12) {
                        KidArt(friend.artName, fallback: friend.symbol, size: 44)
                        Text("New friend: \(friend.name) wants to play!").font(.kidHeadline)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .kidCard(.quiet, tint: theme.success.opacity(0.3))
                }
                if let story {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "book.pages.fill").font(.largeTitle).foregroundStyle(cat.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(story.title).font(.kidHeadline)
                            Text(story.story).font(.kidBody)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .kidCard(.quiet, tint: cat.tint.opacity(0.18))
                }
                HStack(spacing: 16) {
                    Button(action: onNext) { Label("Next puzzle", systemImage: "arrow.right") }
                        .buttonStyle(KidButtonStyle(tint: theme.success))
                        .accessibilityIdentifier("next-puzzle")
                    Button(action: onHome) { Label("Home", systemImage: "house.fill") }
                        .buttonStyle(KidButtonStyle(.soft))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(theme.ink)
        .padding(28)
        .frame(maxWidth: 860)
        .background(.white, in: RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    }
}
