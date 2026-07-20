import SpriteKit
import SwiftUI
import LearningUI

struct MissionView: View {
    let shark: SharkDefinition
    let onComplete: () -> Void
    @Environment(GameStore.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var progress = 0
    @State private var started = false
    @State private var scene: MissionScene

    init(shark: SharkDefinition, onComplete: @escaping () -> Void) {
        self.shark = shark
        self.onComplete = onComplete
        _scene = State(initialValue: MissionScene(mission: shark.mission, size: CGSize(width: 1100, height: 620)))
    }

    var body: some View {
        ZStack {
            OceanBackdrop()
            VStack(spacing: 14) {
                HStack {
                    Button("Back", systemImage: "chevron.left") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.2))
                    VStack(alignment: .leading) {
                        Text(shark.mission.title).font(.largeTitle.weight(.black))
                        Text("\(progress) of \(shark.mission.targetCount)").font(.headline)
                    }
                    Spacer()
                    ProgressView(value: Double(progress), total: Double(shark.mission.targetCount))
                        .tint(.yellow)
                        .frame(width: 260)
                        .scaleEffect(y: 2)
                }

                if !started {
                    VStack(spacing: 20) {
                        SpeciesImageView(shark: shark, contentMode: .fit)
                            .frame(width: 360, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        ReadAlongView(sentences: shark.mission.instructions.sentences(for: game.readingMode)) {
                            started = true
                        }
                    }
                    .frame(maxWidth: 900)
                } else if progress < shark.mission.targetCount {
                    SpriteView(scene: scene)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(alignment: .top) {
                            Text("Tap the \(sceneTargetName)")
                                .font(.title2.weight(.black))
                                .padding(.horizontal, 24).padding(.vertical, 12)
                                .background(.black.opacity(0.42), in: Capsule())
                                .padding()
                        }
                } else {
                    VStack(spacing: 24) {
                        Text("🌟").font(.system(size: 110))
                        Text(shark.mission.completion)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                        Button("Answer three picture questions") { onComplete() }
                            .font(.title2.bold())
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                }
            }
            .padding(28)
            .foregroundStyle(.white)
        }
        .onAppear {
            scene.onProgress = { value in
                Task { @MainActor in progress = value }
            }
        }
    }

    private var sceneTargetName: String {
        switch shark.mission.kind {
        case "filterFeed": "plankton sparkle"
        case "electrosense": "electric clue"
        case "suctionForage": "crab"
        case "camouflageFind": "hidden shell"
        case "tailStrike": "schooling fish"
        case "tidalWalk": "next rock"
        case "jawStrike": "deep-sea fish"
        case "energyTrail": "snowy scent clue"
        default: "clue"
        }
    }
}
