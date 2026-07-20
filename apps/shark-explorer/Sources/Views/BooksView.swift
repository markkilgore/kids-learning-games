import SwiftUI

struct BooksView: View {
    @Environment(GameStore.self) private var game
    @State private var selectedBook = 0
    private let catalog = ContentStore.shared.catalog

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { game.showMap() } label: { Label("Ocean Map", systemImage: "map.fill") }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.18))
                    .frame(minHeight: 58)
                Text("Henry’s Ocean Library")
                    .font(.largeTitle.weight(.black))
                Spacer()
                Picker("Book", selection: $selectedBook) {
                    Text("Shark Book").tag(0)
                    Text("Ocean Words").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 420)
            }

            if selectedBook == 0 { sharkBook } else { wordBook }
        }
        .padding(28)
        .foregroundStyle(.white)
    }

    private var sharkBook: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 5), spacing: 18) {
                ForEach(catalog.sharks) { shark in
                    let earned = game.completedSharks.contains(shark.id)
                    VStack(spacing: 10) {
                        if earned {
                            SpeciesImageView(shark: shark)
                                .frame(height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            Text("❔").font(.system(size: 64))
                        }
                        Text(earned ? shark.name : "Shark page")
                            .font(.title3.weight(.black))
                        Text(earned ? shark.bookFact : "Complete this shark’s mission to collect its page.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .background((earned ? shark.tint : .gray).opacity(0.28), in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
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
