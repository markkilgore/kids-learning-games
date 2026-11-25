import SpriteKit
import SwiftUI
import LearningUI
import Narration

struct EncounterView: View {
    let shark: SharkDefinition
    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @State private var sheet: EncounterSheet?
    @State private var showMission = false
    @State private var toast: (symbol: String, text: String)?
    @State private var habitat: HabitatScene

    init(shark: SharkDefinition) {
        self.shark = shark
        _habitat = State(initialValue: HabitatScene(shark: shark, size: CGSize(width: 700, height: 350)))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                KidTopBar(shark.name, subtitle: shark.scientificName, back: KidBackButton("Ocean Map", systemImage: "map.fill") { game.showMap() }) {
                    if game.completedSharks.contains(shark.id) {
                        Label("Page collected", systemImage: "checkmark.seal.fill")
                            .font(.kidLabel)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 20) {
                    SpriteView(scene: habitat)
                        .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shark.region.uppercased())
                                    .font(.caption.bold())
                                    .tracking(2)
                                Text(shark.bookFact)
                                    .font(.kidBody.weight(.bold))
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(16)
                            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous))
                            .padding(14)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)

                    VStack(spacing: 14) {
                        Button { sheet = .discover } label: {
                            BigFeatureLabel(symbol: "sparkles", title: "Discover", subtitle: "Meet this shark", color: shark.tint)
                        }
                        .accessibilityIdentifier("discover")

                        Button { showMission = true } label: {
                            BigFeatureLabel(symbol: shark.mission.symbol, title: "Play", subtitle: shark.mission.title, color: .orange)
                                .overlay(alignment: .topTrailing) { MissionStars(count: game.stars(for: shark), size: 18).padding(12) }
                        }
                        .accessibilityIdentifier("play-mission")
                    }
                    .buttonStyle(PressableStyle())
                    .frame(width: 320)
                }
                // Taller on bigger iPads so the tank, not empty water, fills the screen.
                .containerRelativeFrame(.vertical) { height, _ in max(300, height * 0.44) }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Explore").font(.kidTitle)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(shark.topics) { topic in
                            let done = game.hasCompleted(topic, for: shark)
                            Button { sheet = .topic(topic) } label: {
                                HStack(spacing: 12) {
                                    KidArt("topic-\(topic.id)", fallback: topic.symbol, size: 40, style: .tile)
                                    Text(topic.title)
                                        .font(.kidHeadline)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if done {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.green)
                                            .accessibilityLabel("Explored")
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 84)
                                .kidCard(done ? .raised : .regular)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .overlay(alignment: .top) {
            if let toast { KidToast(symbol: toast.symbol, text: toast.text).padding(.top, 20) }
        }
        // Full screen: the standard iPad sheet is too narrow for the read-along controls.
        .fullScreenCover(item: $sheet) { active in
            NarrationSheet(shark: shark, active: active) {
                if case .topic(let topic) = active { finished(topic) }
                sheet = nil
            }
        }
        .fullScreenCover(isPresented: $showMission) {
            MissionFlowView(shark: shark, level: game.missionLevel(for: shark)) { showMission = false }
        }
        .onChange(of: sheet == nil && !showMission) { _, visible in habitat.isPaused = !visible }
    }

    private func finished(_ topic: ExploreTopic) {
        let wasDone = game.hasCompleted(topic, for: shark)
        let revealed = game.completeTopic(topic, for: shark)
        guard !wasDone else { return }
        let line: SharkLine = revealed.isEmpty ? .topicDone : .traitUnlocked
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            feedback.play(revealed.isEmpty ? .correct : .unlock)
            narration.play(line.text, after: 0.6)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                toast = revealed.first.map { ($0.symbol, "New trait card: \($0.title)") } ?? ("✅", "\(topic.title) explored!")
            }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation { toast = nil }
        }
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
        ZStack {
            LinearGradient(colors: [KidTheme.shark.background[0], shark.tint.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                KidTopBar(title, back: KidBackButton("Close", systemImage: "xmark") { dismiss() })
                    .padding([.horizontal, .top], 24)
                ReadAlongView(sentences: narration.sentences(for: game.readingMode), vocabulary: vocabulary) {
                    onDone()
                    dismiss()
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
    }

    private var title: String {
        switch active { case .discover: "Discover \(shark.name)"; case .topic(let topic): "\(topic.symbol) \(topic.title)" }
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
                .frame(width: 66, height: 66)
                .background(.white.opacity(0.22), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.kidTitle)
                Text(subtitle).font(.kidLabel).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.title2.bold())
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidCard(.raised, tint: color, radius: KidTheme.Radius.large)
    }
}
