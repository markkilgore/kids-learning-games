import LearningUI
import Narration
import SwiftUI

struct CatHomeView: View {
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var lockedHint: CatDefinition?

    private var visibleCats: [CatDefinition] { CatContent.cats.filter { $0.locationID == game.selectedLocationID } }

    var body: some View {
        @Bindable var game = game
        VStack(spacing: 16) {
            KidTopBar(CatAppConfiguration.value.identity.childFacingName, subtitle: "Solve puzzles to make cat friends") {
                Label("\(game.totalFriendship)", systemImage: "heart.fill")
                    .font(.kidTitle)
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: KidTheme.touchTarget)
                    .background(theme.cardFill(.regular), in: Capsule())
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(game.totalFriendship) friendship hearts")
                Button { game.showJournal() } label: { Label("Journal", systemImage: "book.closed.fill") }
                    .buttonStyle(KidButtonStyle(compact: true))
                    .accessibilityIdentifier("cat-journal")
                ParentGateButton { game.showSettings() }
            }

            HStack(spacing: 16) {
                WeeklyLessonsButton(resource: "cat-weeks", namespace: CatAppConfiguration.value.storageNamespace, guide: "🐈", color: theme.primary)
                KidTabs(selection: $game.selectedLocationID, items: CatContent.locations.map { .init($0.id, $0.name, systemImage: $0.symbol) })
                    .frame(maxWidth: 460)
                Spacer(minLength: 0)
            }

            HStack(spacing: 16) {
                ForEach(visibleCats) { cat in
                    CatCard(cat: cat, unlocked: game.isUnlocked(cat), friendship: game.friendship(for: cat), heartsNeeded: game.heartsNeeded(for: cat)) {
                        if game.isUnlocked(cat) { game.open(cat) } else { showLockedHint(for: cat) }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .id(game.selectedLocationID)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        .padding(24)
        .overlay(alignment: .bottom) {
            if let lockedHint {
                let needed = game.heartsNeeded(for: lockedHint)
                KidToast(symbol: "💗", text: "Earn \(needed) more \(needed == 1 ? "heart" : "hearts") to meet \(lockedHint.name)")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear { narration.stop() }
    }

    private func showLockedHint(for cat: CatDefinition) {
        feedback.play(.wrong)
        narration.play(CatLine.locked.text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { lockedHint = cat }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if lockedHint == cat { withAnimation { lockedHint = nil } }
        }
    }
}

private struct CatCard: View {
    let cat: CatDefinition
    let unlocked: Bool
    let friendship: Int
    let heartsNeeded: Int
    let action: () -> Void
    @Environment(\.kidTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggles = 0

    var body: some View {
        Button {
            if !unlocked, !reduceMotion { withAnimation(.linear(duration: 0.45)) { wiggles += 1 } }
            action()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(cat.tint.opacity(unlocked ? 0.22 : 0.1)).frame(width: 130, height: 130)
                    KidArt(cat.artName, fallback: cat.symbol, size: 86)
                        .saturation(unlocked ? 1 : 0)
                        .opacity(unlocked ? 1 : 0.35)
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(theme.ink.opacity(0.7))
                    }
                }
                Text(cat.name).font(.kidTitle)
                if unlocked {
                    Text("Loves \(cat.favoriteThing)")
                        .font(.kidLabel)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.mutedInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Label("\(friendship)", systemImage: "heart.fill")
                        .font(.kidHeadline)
                        .foregroundStyle(.pink)
                    StoryDots(revealed: cat.revealedStory(for: friendship).count, total: cat.backstory.count, tint: cat.tint)
                } else {
                    Label("\(heartsNeeded) more", systemImage: "heart")
                        .font(.kidHeadline)
                        .foregroundStyle(theme.mutedInk)
                }
            }
            .foregroundStyle(theme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: 360)
            .kidCard(unlocked ? .regular : .quiet, radius: KidTheme.Radius.large)
            .overlay(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous).strokeBorder(cat.tint.opacity(unlocked ? 0.7 : 0.25), lineWidth: 4))
        }
        .buttonStyle(PressableStyle())
        .modifier(ShakeEffect(shakes: wiggles))
        .accessibilityLabel(unlocked ? "Play math with \(cat.name)" : "\(cat.name), locked. Earn \(heartsNeeded) more hearts.")
        .accessibilityIdentifier("cat-\(cat.id)")
    }
}

/// One dot per story page, filled once that page has been revealed.
struct StoryDots: View {
    let revealed: Int
    let total: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { page in
                Image(systemName: page < revealed ? "book.pages.fill" : "book.pages")
                    .font(.system(size: 17))
                    .foregroundStyle(page < revealed ? tint : tint.opacity(0.35))
            }
        }
        .accessibilityLabel("\(revealed) of \(total) story pages")
    }
}
