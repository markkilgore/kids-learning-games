import SwiftUI
import LearningUI
import Narration

struct RootView: View {
    @State private var game = GameStore()
    @State private var narration = NarrationCoordinator(configuration: SharkAppConfiguration.value.narration)

    var body: some View {
        ZStack {
            OceanBackdrop()
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
        .environment(game)
        .environment(narration)
        .task { game.load() }
    }
}

struct OceanBackdrop: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let gradient = Gradient(colors: [Color(hex: "#041E42"), Color(hex: "#006D8F"), Color(hex: "#00A6A6")])
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<28 {
                    let phase = Double(index) * 1.73
                    let x = (Double(index * 89 % 997) / 997.0) * size.width
                    let y = size.height - ((time * (10 + Double(index % 5)) + phase * 90).truncatingRemainder(dividingBy: size.height + 50))
                    let diameter = CGFloat(4 + index % 9)
                    context.opacity = 0.18
                    context.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: .color(.white), lineWidth: 1.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}
