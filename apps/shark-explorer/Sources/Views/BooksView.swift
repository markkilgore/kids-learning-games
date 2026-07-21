import SwiftUI
import UIKit

struct BooksView: View {
    @Environment(GameStore.self) private var game
    @State private var selectedBook = 0
    @State private var selectedSharkID: String?
    private let catalog = ContentStore.shared.catalog

    private var selectedShark: SharkDefinition? {
        catalog.sharks.first { $0.id == selectedSharkID }
    }

    private var collectedTraitCount: Int {
        catalog.sharks.reduce(into: 0) { count, shark in
            count += shark.traits.filter { game.hasUnlocked($0, for: shark) }.count
        }
    }

    private var totalTraitCount: Int { catalog.sharks.reduce(0) { $0 + $1.traits.count } }

    var body: some View {
        VStack(spacing: 18) {
            ViewThatFits(in: .horizontal) {
                expandedHeader.frame(minWidth: 1_080)
                compactHeader
            }

            if selectedBook == 0 { passport } else { wordBook }
        }
        .padding(28)
        .foregroundStyle(.white)
    }

    private var expandedHeader: some View {
        HStack {
            mapButton
            Text("Henry’s Shark Passport")
                .font(.largeTitle.weight(.black))
            Spacer()
            bookPicker
                .frame(width: 420)
        }
    }

    private var compactHeader: some View {
        VStack(spacing: 12) {
            HStack {
                mapButton
                Text("Henry’s Shark Passport")
                    .font(.title.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            bookPicker
                .frame(maxWidth: 520)
        }
    }

    private var mapButton: some View {
        Button { game.showMap() } label: { Label("Ocean Map", systemImage: "map.fill") }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.18))
            .frame(minHeight: 58)
    }

    private var bookPicker: some View {
        Picker("Book", selection: $selectedBook) {
            Text("Shark Passport").tag(0)
            Text("Ocean Words").tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var passport: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(.cyan.opacity(0.25))
                            .frame(width: 96, height: 96)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 42, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ocean Explorer")
                            .font(.title.weight(.black))
                        Text("Complete a shark’s mission to collect its page. Explore a topic to unlock a trait card.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer()
                    PassportCount(value: "\(game.completedCount)/\(catalog.sharks.count)", title: "pages")
                    PassportCount(value: "\(collectedTraitCount)/\(totalTraitCount)", title: "traits")
                    PassportCount(value: "\(game.collectedWords.count)", title: "words")
                }
                .padding(20)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 26))

                Text("Shark Pages")
                    .font(.title2.weight(.black))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                    ForEach(catalog.sharks) { shark in
                        passportPageButton(for: shark)
                    }
                }

                if let selectedShark {
                    PassportDetail(shark: selectedShark)
                        .environment(game)
                } else {
                    ContentUnavailableView(
                        "Your first passport page is waiting",
                        systemImage: "fish.fill",
                        description: Text("Finish a shark mission, then return here to open its page and trait cards."))
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func passportPageButton(for shark: SharkDefinition) -> some View {
        let earned = game.completedSharks.contains(shark.id)
        return Button {
            guard earned else { return }
            selectedSharkID = shark.id
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if earned {
                        SpeciesImageView(shark: shark)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                    }
                    if earned {
                        Image(systemName: selectedSharkID == shark.id ? "checkmark.seal.fill" : "book.closed.fill")
                            .foregroundStyle(.yellow)
                            .padding(7)
                            .background(.black.opacity(0.5), in: Circle())
                            .padding(5)
                    }
                }
                Text(earned ? shark.name : "Shark page")
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(earned ? "\(shark.traits.filter { game.hasUnlocked($0, for: shark) }.count)/\(shark.traits.count) traits" : "Finish mission")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 142)
            .background((earned ? shark.tint : .gray).opacity(selectedSharkID == shark.id ? 0.54 : 0.24), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selectedSharkID == shark.id ? .white : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(earned ? "Open \(shark.name) passport page" : "\(shark.name) passport page locked")
    }

    private var wordBook: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 4), spacing: 18) {
                ForEach(catalog.vocabulary) { word in
                    let earned = game.collectedWords.contains(word.id)
                    VStack(spacing: 10) {
                        Text(earned ? word.symbol : "🔒").font(.system(size: 58))
                        Text(earned ? word.word : "Ocean Word").font(.title2.weight(.black))
                        Text(earned ? word.explanation : "Find a shark that uses this word.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 190)
                    .background(.cyan.opacity(earned ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
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
                            .font(.caption.bold())
                            .lineLimit(3)
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
        .background(shark.tint.opacity(0.28), in: RoundedRectangle(cornerRadius: 28))
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
            Text(unlocked ? trait.description : "Explore \(trait.unlockTopicID) to reveal this trait card.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(.black.opacity(unlocked ? 0.16 : 0.26), in: RoundedRectangle(cornerRadius: 18))
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
