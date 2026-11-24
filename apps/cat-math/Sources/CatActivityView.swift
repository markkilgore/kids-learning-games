import LearningEngine
import LearningUI
import Narration
import SwiftUI

/// A round with a cat: its story page first, then three puzzles set in that scene, then a celebration.
struct CatActivityView: View {
    private enum Phase { case story, puzzle, celebrate }

    let cat: CatDefinition
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var phase = Phase.story
    @State private var challenge: MathChallenge
    /// Changes with every new puzzle, so a late "next puzzle" timer cannot skip one.
    @State private var puzzleNumber = 0
    @State private var wrongChoices: Set<Int> = []
    @State private var correct = false
    @State private var counted = 0
    @State private var praise: String?
    /// Cats that came out of hiding during this round, shown at the celebration.
    @State private var newFriends: [CatDefinition] = []
    /// The story page this round opened, if it opened one.
    @State private var newPage: CatStoryBeat?
    @State private var selectedReward: CatRewardAction?
    @State private var rewardMotion = false
    @State private var celebration = 0

    init(cat: CatDefinition, challenge: MathChallenge) {
        self.cat = cat
        _challenge = State(initialValue: challenge)
    }

    private var friendship: Int { game.friendship(for: cat) }
    private var roundLength: Int { CatDefinition.puzzlesPerRound }
    /// Puzzles solved in the round on screen; a finished round shows all of them.
    private var solvedInRound: Int { phase == .celebrate ? roundLength : cat.solvedInRound(for: friendship) }

    var body: some View {
        VStack(spacing: 16) {
            KidTopBar(
                phase == .story ? "\(cat.name)’s story" : "Math time with \(cat.name)",
                subtitle: phase == .story ? "Page \(cat.storyPage(for: friendship) + 1) of \(cat.backstory.count)" : challenge.skill.displayName,
                back: KidBackButton { goHome() }
            ) {
                HStack(spacing: 18) {
                    RoundSteps(solved: solvedInRound, total: roundLength, tint: cat.tint)
                    Label("\(friendship)", systemImage: "heart.fill")
                        .font(.kidTitle)
                        .foregroundStyle(.pink)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(friendship) hearts with \(cat.name)")
                }
            }

            if phase == .story {
                storyPage
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                HStack(alignment: .top, spacing: 18) {
                    sceneColumn.frame(width: 260)
                    puzzleColumn
                }
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(24)
        .foregroundStyle(theme.ink)
        .overlay {
            if phase == .celebrate {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    CatRewardCard(
                        cat: cat,
                        newPage: newPage,
                        newFriends: newFriends,
                        selectedReward: selectedReward,
                        rewardMotion: rewardMotion,
                        onReward: chooseReward,
                        onNext: nextRound,
                        onHome: goHome
                    )
                    .padding(40)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .overlay { CelebrationView(trigger: celebration) }
        .onAppear { tellStory() }
    }

    // MARK: Story page

    private var storyPage: some View {
        let story = cat.storyBeat(for: friendship)
        let left = roundLength - cat.solvedInRound(for: friendship)
        return HStack(spacing: 24) {
            VStack(spacing: 14) {
                KidArt(cat.artName, fallback: cat.symbol, size: 190)
                StoryDots(revealed: cat.revealedStory(for: friendship).count, total: cat.backstory.count, tint: cat.tint)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(story.title).font(.kidTitle).foregroundStyle(cat.tint)
                if let focus = story.focus { FocusLegend(focus: focus, tint: cat.tint) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(story.sentences, id: \.self) { sentence in
                            StorySentence(sentence: sentence, focus: story.focus, tint: cat.tint)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                Label(
                    friendship >= cat.lastPageFriendship
                        ? "Solve \(left) \(left == 1 ? "puzzle" : "puzzles") to earn a treat"
                        : "Solve \(left) \(left == 1 ? "puzzle" : "puzzles") to turn the page",
                    systemImage: "pawprint.fill"
                )
                .font(.kidHeadline)
                .foregroundStyle(theme.mutedInk)
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    Button { tellStory() } label: { Label("Hear it again", systemImage: "speaker.wave.2.fill") }
                        .buttonStyle(KidButtonStyle(.soft, tint: cat.tint))
                    Button { startPuzzles() } label: { Label("Help \(cat.name)", systemImage: "arrow.right") }
                        .buttonStyle(KidButtonStyle(tint: theme.success))
                        .accessibilityIdentifier("start-round")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidCard(radius: KidTheme.Radius.large)
    }

    /// Reads the page aloud, then says what to do next when a round is just beginning.
    private func tellStory() {
        var lines = cat.storyBeat(for: friendship).sentences
        if cat.solvedInRound(for: friendship) == 0 {
            lines.append((friendship >= cat.lastPageFriendship ? CatLine.roundBonus : CatLine.roundIntro).text)
        }
        narration.playSequence(lines, gap: 0.45)
    }

    private func startPuzzles() {
        narration.stop()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { phase = .puzzle }
        narration.play(challenge.prompt, after: 0.4)
    }

    // MARK: Puzzles

    /// Keeps the story in view while solving: who we are helping, where, and how far through the round.
    private var sceneColumn: some View {
        let story = cat.storyBeat(for: correct ? friendship - 1 : friendship)
        return VStack(spacing: 12) {
            KidArt(cat.artName, fallback: cat.symbol, size: 150)
                .scaleEffect(correct ? 1.1 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.45), value: correct)
            Text(story.title).font(.kidHeadline).multilineTextAlignment(.center)
            Text(story.puzzleLead.trimmingCharacters(in: CharacterSet(charactersIn: ", ")))
                .font(.kidBody)
                .foregroundStyle(theme.mutedInk)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Text("Puzzle \(cat.solvedInRound(for: correct ? friendship - 1 : friendship) + 1) of \(roundLength)")
                .font(.kidHeadline)
                .contentTransition(.numericText())
            Text("Finish all \(roundLength) to celebrate with \(cat.name)")
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .disabled(correct)
            }

            MathVisualView(challenge: challenge, objectArt: cat.countingArtName, counted: $counted) { number in
                feedback.play(.pop)
                narration.play(CatLine.count(number))
            }
            .id(puzzleNumber)
            // Counting aloud after the answer would cut off the praise that moves the round on.
            .allowsHitTesting(!correct)
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

            if let praise {
                Label(praise, systemImage: "star.fill")
                    .font(.kidHeadline)
                    .foregroundStyle(theme.success)
                    .transition(.scale.combined(with: .opacity))
            } else if !wrongChoices.isEmpty {
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
        game.recordAnswer(for: challenge.skill, correct: choice == challenge.answer, isFirstAnswer: wrongChoices.isEmpty)
        guard choice == challenge.answer else {
            feedback.play(.wrong)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { _ = wrongChoices.insert(choice) }
            // Wait for the "try again" sound before speaking over it.
            narration.play(CatLine.retry.text, after: 0.45)
            return
        }
        correct = true
        let pageBefore = cat.storyPage(for: friendship)
        withAnimation { newFriends += game.completeActivity(for: cat) }
        if cat.solvedInRound(for: friendship) == 0 {
            finishRound(openedPage: cat.storyPage(for: friendship) > pageBefore)
        } else {
            praiseThenContinue()
        }
    }

    /// A quick "well done", then straight on to the next puzzle in the round.
    private func praiseThenContinue() {
        let line = WeeklySpokenLines.praise[friendship % WeeklySpokenLines.praise.count]
        let solved = puzzleNumber
        feedback.play(.correct)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { praise = line }
        narration.play(line, after: 0.5) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                nextPuzzle(after: solved)
            }
        }
        // If the praise is cut short (a phone call, sound switched off mid-line), still move on.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            nextPuzzle(after: solved)
        }
    }

    private func nextPuzzle(after solved: Int) {
        guard solved == puzzleNumber, phase == .puzzle, correct else { return }
        showNextPuzzle()
        narration.play(challenge.prompt, after: 0.4)
    }

    private func showNextPuzzle() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            challenge = game.nextChallenge(for: cat)
            puzzleNumber += 1
            wrongChoices = []
            correct = false
            counted = 0
            praise = nil
        }
    }

    // MARK: Celebration

    private func finishRound(openedPage: Bool) {
        newPage = openedPage ? cat.storyBeat(for: friendship) : nil
        feedback.play(.celebrate)
        celebration += 1
        // Let the fanfare ring before the voice comes in.
        narration.play("You did it! \(cat.name)’s friendship grew.", after: 1.4)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = .celebrate }
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
        var lines = [reward.celebration(for: cat)]
        if !newFriends.isEmpty { lines.append(CatLine.newFriend.text) }
        if newPage != nil { lines.append(CatLine.newPage.text) }
        narration.stop()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard phase == .celebrate else { return }
            narration.playSequence(lines, gap: 0.5)
        }
    }

    /// After a celebration: read the page the round opened, or go straight to more puzzles.
    private func nextRound() {
        narration.stop()
        let opensStory = newPage != nil
        showNextPuzzle()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            newFriends = []
            newPage = nil
            selectedReward = nil
            rewardMotion = false
            phase = opensStory ? .story : .puzzle
        }
        if opensStory { tellStory() } else { narration.play(challenge.prompt, after: 0.4) }
    }

    private func goHome() {
        narration.stop()
        game.showHome()
    }
}

/// One story sentence as tappable words. The week's pattern words are underlined, its sight words are
/// shaded, and the word being read aloud lights up so a child can follow along.
private struct StorySentence: View {
    let sentence: String
    let focus: ReadingFocus?
    let tint: Color
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(\.kidTheme) private var theme

    var body: some View {
        let reading = narration.state == .playing && narration.text == sentence
        WordFlowLayout(spacing: 2) {
            ForEach(sentence.wordTokens) { token in
                let kind = focus?.kind(of: token.text)
                let spoken = reading && narration.currentWordIndex == token.id
                Button { narration.speakWord(token.text, at: token.id, in: sentence) } label: {
                    Text(leading(of: token) + token.text + sentence.punctuation(after: token.range))
                        .font(.system(size: 23, weight: kind == nil ? .semibold : .heavy, design: .rounded))
                        .foregroundStyle(kind == .pattern ? tint : theme.ink)
                        .underline(kind == .pattern, color: tint)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            spoken ? Color.yellow.opacity(0.75) : kind == .sight ? theme.secondary.opacity(0.22) : .clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(token.text)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(reading ? 0.12 : 0), in: RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
        .animation(.easeInOut(duration: 0.15), value: narration.currentWordIndex)
    }

    /// An opening quotation mark belongs with the word after it.
    private func leading(of token: WordToken) -> String {
        guard token.range.location > 0 else { return "" }
        let before = (sentence as NSString).substring(with: NSRange(location: token.range.location - 1, length: 1))
        return before == "‘" ? before : ""
    }
}

/// Says what the marks on a story page mean.
private struct FocusLegend: View {
    let focus: ReadingFocus
    let tint: Color
    @Environment(\.kidTheme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Text(focus.title)
                .font(.kidLabel.weight(.heavy))
                .foregroundStyle(tint)
                .underline(color: tint)
            Text("sight words")
                .font(.kidLabel.weight(.heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.secondary.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Label("Tap a word to hear it", systemImage: "hand.tap.fill")
                .font(.kidLabel)
                .foregroundStyle(theme.mutedInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reading-focus")
    }
}

/// Paw prints that fill in as the puzzles in a round are solved.
private struct RoundSteps: View {
    let solved: Int
    let total: Int
    let tint: Color
    @Environment(\.kidTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { step in
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(step < solved ? tint : theme.ink.opacity(0.18))
                    .scaleEffect(step < solved ? 1.1 : 1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: solved)
        .accessibilityElement()
        .accessibilityLabel("\(solved) of \(total) puzzles solved")
    }
}

/// The puzzle's picture. Countable objects can be tapped: each tap numbers the object and says the count.
private struct MathVisualView: View {
    let challenge: MathChallenge
    /// Bundled drawing of the counting object; the challenge's emoji stands in when it is missing.
    let objectArt: String
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
            KidArt(objectArt, fallback: challenge.icon, size: 42, style: .plain)
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
            KidArt(objectArt, fallback: challenge.icon, size: 40, style: .plain)
            Text(text)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .frame(minWidth: 84, minHeight: 64)
                .background(theme.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
        }
    }
}

/// Shown when a round is finished: celebrate with the cat, then read the new story page, keep playing or go home.
private struct CatRewardCard: View {
    let cat: CatDefinition
    /// The story page this round opened, if any; it is read on the next screen.
    let newPage: CatStoryBeat?
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
                    rewardIcon
                        .zIndex(1)
                        .opacity(selectedReward == nil ? 0 : 1)
                        .offset(x: selectedReward == .trick ? 0 : 70, y: selectedReward == .trick ? -70 : 20)
                    KidArt(cat.rewardArtName, fallback: cat.symbol, size: 100)
                        .scaleEffect(selectedReward == .meal && rewardMotion ? 1.14 : 1)
                        .rotationEffect(.degrees(selectedReward == .trick && rewardMotion ? 16 : 0))
                        .offset(x: selectedReward == .treat && rewardMotion ? 16 : 0, y: selectedReward == .trick && rewardMotion ? -24 : 0)
                }
                .frame(width: 190, height: 140)
                VStack(alignment: .leading, spacing: 6) {
                    Label("You helped \(cat.name)!", systemImage: "heart.fill")
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
                if let newPage {
                    HStack(spacing: 14) {
                        Image(systemName: "book.pages.fill").font(.largeTitle).foregroundStyle(cat.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("New story page").font(.kidLabel).foregroundStyle(theme.mutedInk)
                            Text(newPage.title).font(.kidHeadline)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .kidCard(.quiet, tint: cat.tint.opacity(0.18))
                }
                HStack(spacing: 16) {
                    Button(action: onNext) { Label(newPage == nil ? "More puzzles" : "Read the story", systemImage: newPage == nil ? "arrow.right" : "book.fill") }
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

    @ViewBuilder private var rewardIcon: some View {
        switch selectedReward {
        case .meal: KidArt("reward-meal", fallback: "🥣", size: 54, style: .plain)
        case .treat: KidArt("reward-treat", fallback: "🐟", size: 54, style: .plain)
        default: Text(cat.trickSymbol).font(.system(size: 54))
        }
    }
}

private extension CatDefinition {
    /// Bundled drawing of the thing this cat's puzzles count, e.g. `count-stepping-stone`.
    var countingArtName: String { "count-" + storyItem.replacingOccurrences(of: " ", with: "-") }

    /// The celebrating pose for the reward card, or the usual portrait when there is none.
    var rewardArtName: String {
        let happy = "\(artName)-happy"
        return UIImage(named: happy) == nil ? artName : happy
    }
}
