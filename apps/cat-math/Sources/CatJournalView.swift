import LearningUI
import Narration
import SwiftUI

struct CatJournalView: View {
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(\.kidTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            KidTopBar("Kate’s Friend Journal", subtitle: "\(game.progress.journaledCatIDs.count) of \(CatContent.cats.count) friends", back: KidBackButton {
                narration.stop()
                game.showHome()
            })
            .padding(.horizontal, 24)
            // Two plain columns: cards differ a lot in height, and a lazy grid re-measures them while scrolling.
            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(0..<2, id: \.self) { column in
                        VStack(spacing: 16) {
                            ForEach(Array(CatContent.cats.enumerated()).filter { $0.offset % 2 == column }, id: \.element.id) { _, cat in
                                CatJournalCard(cat: cat, met: game.progress.journaledCatIDs.contains(cat.id))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.visible)
            .ignoresSafeArea(edges: .bottom)
        }
        .padding(.top, 24)
        .foregroundStyle(theme.ink)
    }
}

private struct CatJournalCard: View {
    let cat: CatDefinition
    let met: Bool
    @Environment(CatGameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(\.kidTheme) private var theme

    var body: some View {
        let friendship = game.friendship(for: cat)
        let stories = cat.revealedStory(for: friendship)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(cat.tint.opacity(met ? 0.22 : 0.08)).frame(width: 84, height: 84)
                    if met { KidArt(cat.artName, fallback: cat.symbol, size: 56) } else { Text("❔").font(.system(size: 50)) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(met ? cat.name : "New friend").font(.kidTitle)
                    Text(met ? "Loves \(cat.favoriteThing)" : "Solve a puzzle together to start this story.")
                        .font(.kidLabel)
                        .foregroundStyle(theme.mutedInk)
                }
                Spacer(minLength: 0)
                if met {
                    Label("\(friendship)", systemImage: "heart.fill").font(.kidHeadline).foregroundStyle(.pink)
                }
            }

            if met {
                ForEach(stories) { story in
                    Button { narration.playSequence(story.sentences, gap: 0.45) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: story.sentences.contains(narration.text) && narration.state == .playing ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundStyle(cat.tint)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.title).font(.kidHeadline).foregroundStyle(cat.tint)
                                Text(story.story).font(.kidBody).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: KidTheme.touchTarget, alignment: .leading)
                        .background(cat.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Hear \(story.title)")
                }
                if let left = cat.puzzlesUntilNextPage(for: friendship) {
                    Label("Solve \(left) more \(left == 1 ? "puzzle" : "puzzles") for the next page", systemImage: "lock.fill")
                        .font(.kidLabel)
                        .foregroundStyle(theme.mutedInk)
                }
                HStack(spacing: 16) {
                    rewardCount(.treat, label: "treats")
                    rewardCount(.meal, label: "meals")
                    rewardCount(.trick, label: "tricks")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .kidCard(met ? .regular : .quiet, radius: KidTheme.Radius.large)
        .overlay(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous).strokeBorder(cat.tint.opacity(met ? 0.5 : 0.15), lineWidth: 3))
    }

    private func rewardCount(_ reward: CatRewardAction, label: String) -> some View {
        Label("\(game.rewardCount(reward, for: cat)) \(label)", systemImage: reward.symbol)
            .font(.kidLabel)
            .foregroundStyle(theme.mutedInk)
    }
}
