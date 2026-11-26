import LearningUI
import Narration
import SwiftUI
import UIKit

struct BooksView: View {
    private enum Book: Hashable { case passport, words }

    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(\.kidTheme) private var theme
    @State private var book = Book.passport
    @State private var selectedSharkID: String?
    @State private var spokenWordID: String?
    private let catalog = ContentStore.shared.catalog

    private var selectedShark: SharkDefinition? {
        catalog.sharks.first { $0.id == selectedSharkID && game.completedSharks.contains($0.id) }
    }

    private var collectedTraitCount: Int {
        catalog.sharks.reduce(into: 0) { count, shark in
            count += shark.traits.filter { game.hasUnlocked($0, for: shark) }.count
        }
    }

    private var totalTraitCount: Int { catalog.sharks.reduce(0) { $0 + $1.traits.count } }

    var body: some View {
        VStack(spacing: 16) {
            KidTopBar(book == .passport ? "Henry’s Shark Passport" : "Henry’s Ocean Words", back: KidBackButton("Ocean Map", systemImage: "map.fill") {
                narration.stop()
                game.showMap()
            }) {
                KidTabs(selection: $book, items: [
                    .init(.passport, "Passport", systemImage: "book.closed.fill"),
                    .init(.words, "Ocean Words", systemImage: "textformat.abc")
                ])
                .frame(width: 430)
            }

            if book == .passport { passport } else { wordBook }
        }
        .padding(24)
        .foregroundStyle(.white)
        .onAppear {
            // Open on the page just earned, or the first collected page, so the book never looks empty.
            selectedSharkID = game.passportSharkID ?? catalog.sharks.first { game.completedSharks.contains($0.id) }?.id
            game.passportSharkID = nil
        }
    }

    private var passport: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 36, weight: .bold))
                        .frame(width: 80, height: 80)
                        .background(.cyan.opacity(0.3), in: Circle())
                    Text("Finish a shark’s mission to collect its page. Explore topics to reveal trait cards.")
                        .font(.kidBody)
                        .foregroundStyle(theme.mutedInk)
                    Spacer(minLength: 8)
                    PassportCount(value: "\(game.completedCount)/\(catalog.sharks.count)", title: "pages")
                    PassportCount(value: "\(collectedTraitCount)/\(totalTraitCount)", title: "traits")
                    PassportCount(value: "\(game.collectedWords.count)", title: "words")
                }
                .padding(18)
                .kidCard()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 10), spacing: 10) {
                    ForEach(catalog.sharks) { shark in
                        passportPageButton(for: shark)
                    }
                }

                if let selectedShark {
                    PassportDetail(shark: selectedShark)
                        .id(selectedShark.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    VStack(spacing: 10) {
                        Text("🦈").font(.system(size: 64))
                        Text(game.completedCount == 0 ? "Your first passport page is waiting" : "Tap a shark page to open it")
                            .font(.kidTitle)
                        if game.completedCount == 0 {
                            Text("Finish a shark mission, then come back to see its page.")
                                .font(.kidBody)
                                .foregroundStyle(theme.mutedInk)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .kidCard(.quiet, radius: KidTheme.Radius.large)
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func passportPageButton(for shark: SharkDefinition) -> some View {
        let earned = game.completedSharks.contains(shark.id)
        let selected = selectedSharkID == shark.id
        return Button {
            guard earned else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedSharkID = shark.id }
        } label: {
            VStack(spacing: 8) {
                Group {
                    if earned {
                        SpeciesImageView(shark: shark)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.black.opacity(0.25))
                    }
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.small, style: .continuous))
                // Twenty pages share two rows, so a name may take two short lines.
                Text(earned ? shark.name.replacingOccurrences(of: " Shark", with: "") : "Hidden")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .frame(height: 36)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 108)
            .kidCard(selected ? .raised : .regular, tint: earned ? shark.tint.opacity(selected ? 0.9 : 0.45) : nil)
            .overlay(RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous).strokeBorder(.yellow.opacity(selected ? 1 : 0), lineWidth: 4))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(earned ? "Open \(shark.name) passport page" : "Hidden passport page, locked")
    }

    private var wordBook: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(catalog.vocabulary) { word in
                    let earned = game.collectedWords.contains(word.id)
                    Button {
                        guard earned else { return }
                        spokenWordID = word.id
                        narration.play(word.word)
                    } label: {
                        VStack(spacing: 8) {
                            Text(earned ? word.symbol : "🔒").font(.system(size: 56))
                            HStack(spacing: 6) {
                                Text(earned ? word.word : "Ocean Word").font(.kidHeadline)
                                if earned { Image(systemName: "speaker.wave.2.fill").font(.kidLabel).foregroundStyle(.cyan) }
                            }
                            Text(earned ? word.explanation : "Find a shark that uses this word.")
                                .font(.kidLabel)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(theme.mutedInk)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 190)
                        .kidCard(earned ? .regular : .quiet, tint: earned ? .cyan.opacity(spokenWordID == word.id ? 0.5 : 0.3) : nil)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(earned ? "Hear the word \(word.word)" : "Ocean Word, locked")
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PassportCount: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.black))
            Text(title.uppercased()).font(.caption2.bold()).tracking(1)
        }
        .frame(minWidth: 72)
    }
}

private struct PassportDetail: View {
    let shark: SharkDefinition
    @Environment(GameStore.self) private var game

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shark.name).font(.title.weight(.black))
                    Text(shark.scientificName).font(.subheadline.italic()).foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Label("Collected page", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }

            HStack(alignment: .top, spacing: 18) {
                SpeciesImageView(shark: shark)
                    .frame(width: 270, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(alignment: .bottomLeading) {
                        Text(shark.bookFact)
                            .font(.kidLabel)
                            .lineLimit(4)
                            .minimumScaleFactor(0.8)
                            .padding(12)
                            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            .padding(10)
                    }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                    ForEach(shark.traits) { trait in
                        PassportTraitCard(trait: trait, shark: shark, unlocked: game.hasUnlocked(trait, for: shark))
                    }
                }
            }
        }
        .padding(22)
        .kidCard(tint: shark.tint.opacity(0.4), radius: KidTheme.Radius.large)
    }
}

private struct PassportTraitCard: View {
    let trait: TraitDefinition
    let shark: SharkDefinition
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if unlocked {
                    TraitArtwork(trait: trait, shark: shark)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black.opacity(0.28))
                }
            }
            .frame(height: 102)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 6) {
                Text(unlocked ? trait.symbol : "🔒")
                Text(unlocked ? trait.title : "Keep exploring")
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(unlocked ? trait.description : "Explore “\(shark.topics.first { $0.id == trait.unlockTopicID }?.title ?? "more topics")” to reveal this card.")
                .font(.kidLabel)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(4)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(.black.opacity(unlocked ? 0.16 : 0.26), in: RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
    }
}

private struct TraitArtwork: View {
    let trait: TraitDefinition
    let shark: SharkDefinition

    var body: some View {
        if let imageAsset = trait.imageAsset, let image = UIImage(named: imageAsset) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel("Illustration of \(trait.title)")
        } else {
            SpeciesImageView(shark: shark)
                .overlay {
                    LinearGradient(colors: [.clear, shark.tint.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                }
        }
    }
}
