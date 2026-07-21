import SpriteKit
import SwiftUI
import LearningUI

struct EncounterView: View {
    let shark: SharkDefinition
    @Environment(GameStore.self) private var game
    @State private var sheet: EncounterSheet?
    @State private var showMission = false
    @State private var showQuestions = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                EncounterHeader(shark: shark, readingModeTitle: game.readingMode.title) {
                    game.showMap()
                } onReplay: {
                    sheet = .discover
                }

                HStack(spacing: 20) {
                    SpriteView(scene: HabitatScene(shark: shark, size: CGSize(width: 700, height: 350)), options: [.allowsTransparency])
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading) {
                                Text(shark.region.uppercased())
                                    .font(.caption.bold())
                                    .tracking(2)
                                Text(shark.bookFact)
                                    .font(.title3.bold())
                                    .lineLimit(2)
                            }
                            .padding(18)
                            .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                            .padding(16)
                        }

                    VStack(spacing: 14) {
                        Button { sheet = .discover } label: {
                            BigFeatureLabel(symbol: "sparkles", title: "Discover", subtitle: "Meet this shark", color: shark.tint)
                        }
                        .buttonStyle(.plain)

                        Button { showMission = true } label: {
                            BigFeatureLabel(symbol: shark.mission.symbol, title: "Play", subtitle: shark.mission.title, color: .orange)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 320)
                }
                .frame(maxHeight: 370)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Explore")
                        .font(.title2.weight(.black))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(shark.topics) { topic in
                            Button { sheet = .topic(topic) } label: {
                                VStack(spacing: 8) {
                                    Text(topic.symbol).font(.system(size: 36))
                                    Text(topic.title).font(.headline)
                                    if game.completedTopics.contains("\(shark.id):\(topic.id)") {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .sheet(item: $sheet) { active in
            NarrationSheet(shark: shark, active: active) {
                if case .topic(let topic) = active { game.completeTopic(sharkID: shark.id, topicID: topic.id) }
                sheet = nil
            }
        }
        .fullScreenCover(isPresented: $showMission) {
            MissionView(shark: shark) {
                showMission = false
                showQuestions = true
            }
            .environment(game)
        }
        .fullScreenCover(isPresented: $showQuestions) {
            QuestionRoundView(shark: shark) {
                game.completeMission(for: shark)
                showQuestions = false
            }
            .environment(game)
        }
    }
}

private struct EncounterHeader: View {
    let shark: SharkDefinition
    let readingModeTitle: String
    let onMap: () -> Void
    let onReplay: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            expandedHeader.frame(minWidth: 1_120)
            compactHeader
        }
    }

    private var expandedHeader: some View {
        HStack {
            mapButton
            sharkTitle
            Spacer()
            readingMode
            replayButton(showsLabel: true)
        }
    }

    private var compactHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                mapButton
                sharkTitle
                Spacer(minLength: 0)
                replayButton(showsLabel: false)
            }
            HStack {
                readingMode
                Spacer()
            }
        }
    }

    private var sharkTitle: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(shark.name)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(shark.scientificName)
                .font(.subheadline.italic())
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var readingMode: some View {
        Label(readingModeTitle, systemImage: "text.book.closed.fill")
            .font(.headline)
    }

    private var mapButton: some View {
        Button(action: onMap) {
            Label("Ocean Map", systemImage: "map.fill")
                .font(.headline)
                .frame(minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.2))
    }

    private func replayButton(showsLabel: Bool) -> some View {
        Button(action: onReplay) {
            if showsLabel {
                Label("Replay", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(minHeight: 54)
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline)
                    .frame(width: 54, height: 54)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(shark.tint)
        .accessibilityLabel("Replay")
    }
}

enum EncounterSheet: Identifiable {
    case discover
    case topic(ExploreTopic)
    var id: String {
        switch self {
        case .discover: "discover"
        case .topic(let topic): topic.id
        }
    }
}

private struct NarrationSheet: View {
    let shark: SharkDefinition
    let active: EncounterSheet
    let onDone: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: "#052B52"), shark.tint.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack {
                    Text(title)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                    ReadAlongView(sentences: narration.sentences(for: game.readingMode), vocabulary: vocabulary) {
                        onDone()
                        dismiss()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark.circle.fill") { dismiss() }
                        .font(.headline)
                }
            }
        }
    }

    private var title: String {
        switch active { case .discover: "Discover \(shark.name)"; case .topic(let topic): topic.title }
    }
    private var narration: NarrativePair {
        switch active { case .discover: shark.discover; case .topic(let topic): topic.narration }
    }
    private var vocabulary: Set<String> {
        Set(ContentStore.shared.catalog.vocabulary.filter { shark.vocabularyIDs.contains($0.id) }.map { $0.word.lowercased() })
    }
}

private struct BigFeatureLabel: View {
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .bold))
                .frame(width: 62, height: 62)
                .background(.white.opacity(0.2), in: Circle())
            VStack(alignment: .leading) {
                Text(title).font(.title2.weight(.black))
                Text(subtitle).font(.subheadline).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.title2.bold())
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 102)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 24))
    }
}
