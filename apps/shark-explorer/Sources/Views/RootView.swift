import SwiftUI
import LearningUI
import Narration

/// Interface lines Shark Explorer speaks; the text lives in `ui-lines.json` so the audio generator sees it too.
enum SharkLine: String, CaseIterable {
    case locked, newShark, pageEarned, traitUnlocked, topicDone, leave, tryAgain, starEarned, starNextTime, allStars

    private static let lines = SpokenLines()
    var text: String { Self.lines[rawValue] }
}

extension KidTheme {
    static let shark = KidTheme(tokens: SharkAppConfiguration.value.theme, ink: .white, isDark: true)
}

struct RootView: View {
    @State private var game = GameStore()
    @State private var sound: SoundSettings
    @State private var narration: NarrationCoordinator
    @State private var feedback: FeedbackPlayer

    init() {
        let sound = SoundSettings()
        _sound = State(initialValue: sound)
        _narration = State(initialValue: NarrationCoordinator(configuration: SharkAppConfiguration.value.narration, settings: sound))
        _feedback = State(initialValue: FeedbackPlayer(settings: sound))
    }

    private var wordMarker: (@Sendable (String) -> WordMark?)? {
        guard game.readingMode == .earlyReader else { return nil }
        let reading = SharkReading.shared
        return { reading.mark($0) }
    }

    var body: some View {
        ZStack {
            OceanBackdrop()
            if let problem = ContentStore.shared.loadError {
                ContentUnavailableView("Shark Explorer needs a grown-up", systemImage: "exclamationmark.triangle.fill", description: Text(problem))
                    .foregroundStyle(.white)
            } else {
                screen
                    .id(game.destination)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: game.destination)
        .environment(game)
        .environment(narration)
        .environment(feedback)
        .environment(sound)
        .environment(\.kidTheme, .shark)
        // Early Reader mode marks the words Henry can sound out and his heart words.
        .environment(\.wordMarker, wordMarker)
        .task { game.load() }
    }

    @ViewBuilder private var screen: some View {
        switch game.destination {
        case .map:
            OceanMapView()
        case .encounter(let sharkID):
            if let shark = ContentStore.shared.catalog.sharks.first(where: { $0.id == sharkID }) {
                EncounterView(shark: shark)
            } else {
                OceanMapView()
            }
        case .books:
            BooksView()
        case .settings:
            ParentSettingsView()
        }
    }
}

/// The deep-water gradient with slowly rising bubbles behind every screen.
struct OceanBackdrop: View {
    @Environment(\.kidTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: theme.background), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                for ray in 0..<5 {
                    var beam = Path()
                    let x = size.width * (0.1 + Double(ray) * 0.2)
                    beam.move(to: CGPoint(x: x, y: 0))
                    beam.addLine(to: CGPoint(x: x + 90, y: 0))
                    beam.addLine(to: CGPoint(x: x - 160, y: size.height))
                    beam.addLine(to: CGPoint(x: x - 330, y: size.height))
                    beam.closeSubpath()
                    context.fill(beam, with: .linearGradient(Gradient(colors: [.white.opacity(0.07), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.8)))
                }
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<28 {
                    let phase = Double(index) * 1.73
                    let x = (Double(index * 89 % 997) / 997.0) * size.width + sin(time * 0.6 + phase) * 6
                    let y = size.height - ((time * (10 + Double(index % 5)) + phase * 90).truncatingRemainder(dividingBy: size.height + 50))
                    let diameter = CGFloat(4 + index % 9)
                    context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: .color(.white.opacity(0.2)), lineWidth: 1.5)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
