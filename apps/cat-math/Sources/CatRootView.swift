import LearningEngine
import LearningUI
import Narration
import SwiftUI
import UIKit

/// Interface lines Cat Math speaks; the text lives in `ui-lines.json` so the audio generator sees it too.
enum CatLine: String, CaseIterable {
    case retry, locked, newFriend, roundIntro, roundBonus, newPage
    case count11, count12, count13, count14, count15, count16, count17, count18, count19, count20

    private static let lines = SpokenLines()
    var text: String { Self.lines[rawValue] }

    /// "One!" through "Twenty!", spoken as a child taps objects to count them.
    static func count(_ number: Int) -> String {
        let shared = WeeklySpokenLines.counts
        if shared.indices.contains(number - 1) { return shared[number - 1] }
        return CatLine(rawValue: "count\(number)")?.text ?? ""
    }
}

extension KidTheme {
    static let cat = KidTheme(tokens: CatAppConfiguration.value.theme, ink: Color(hex: "#5B376E"), isDark: false)
}

extension CatDefinition {
    var tint: Color { Color(hex: color) }
    /// Bundled illustration name; `KidArt` falls back to the emoji until the art ships.
    var artName: String { "cat-\(id)" }
}

struct CatRootView: View {
    @State private var game = CatGameStore()
    @State private var sound: SoundSettings
    @State private var narration: NarrationCoordinator
    @State private var feedback: FeedbackPlayer

    init() {
        let sound = SoundSettings()
        _sound = State(initialValue: sound)
        _narration = State(initialValue: NarrationCoordinator(configuration: CatAppConfiguration.value.narration, settings: sound))
        _feedback = State(initialValue: FeedbackPlayer(settings: sound))
    }

    var body: some View {
        ZStack {
            CatBackdrop(locationID: game.selectedLocationID, showsDecorations: game.destination == .home)
            screen
                .id(game.destination)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
        .animation(.easeInOut(duration: 0.3), value: game.destination)
        .environment(game)
        .environment(narration)
        .environment(feedback)
        .environment(sound)
        .environment(\.kidTheme, .cat)
        .task { game.load() }
    }

    @ViewBuilder private var screen: some View {
        switch game.destination {
        case .home:
            CatHomeView()
        case .activity(let catID):
            if let cat = CatContent.cats.first(where: { $0.id == catID }) {
                CatActivityView(cat: cat, challenge: game.nextChallenge(for: cat))
            } else {
                CatHomeView()
            }
        case .journal:
            CatJournalView()
        case .settings:
            CatSettingsView()
        }
    }
}

/// House, garden or meadow behind every screen: bundled artwork when present, otherwise a soft gradient with decorations.
private struct CatBackdrop: View {
    let locationID: String
    /// Emoji decorations only suit the home screen; elsewhere they show through translucent cards.
    var showsDecorations = true

    private var isGarden: Bool { locationID != "house" }
    private var gradient: [Color] {
        switch locationID {
        case "garden": [Color(hex: "#DDF4D4"), Color(hex: "#BDE0FE"), Color(hex: "#FFF4D6")]
        case "meadow": [Color(hex: "#FFF1C1"), Color(hex: "#D8F0C0"), Color(hex: "#BDE0FE")]
        default: [Color(hex: "#FFF4D6"), Color(hex: "#FADADD"), Color(hex: "#E9D5FF")]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let image = UIImage(named: "backdrop-\(locationID)") {
                // Drawn as an overlay so the picture's own size never stretches the screen layout.
                Color.clear
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipped()
                    .overlay(.white.opacity(0.35))
            } else if showsDecorations {
                // Decorations sit along the bottom edge, clear of the header controls.
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        Text(isGarden ? "🌻 🌿" : "🪟 🪴").font(.system(size: 70))
                        Spacer()
                        Text(isGarden ? "🌷 🌼" : "🧶 🛋️").font(.system(size: 70))
                    }
                    .opacity(0.3)
                    .padding(.horizontal, 20)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: locationID)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
