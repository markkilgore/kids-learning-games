import SwiftUI

struct OceanMapView: View {
    @Environment(GameStore.self) private var game
    private let catalog = ContentStore.shared.catalog

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Henry’s Shark Explorer")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                    Text("Choose an ocean friend to discover")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                headerButton("books.vertical.fill", "My Books") { game.destination = .books }
                ParentGateButton { game.destination = .settings }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            GeometryReader { proxy in
                ZStack {
                    WorldMapShape()
                        .fill(.mint.opacity(0.16))
                        .overlay(WorldMapShape().stroke(.white.opacity(0.15), lineWidth: 2))
                        .padding(30)

                    ForEach(catalog.sharks) { shark in
                        SharkMapNode(shark: shark, unlocked: game.isUnlocked(shark)) {
                            game.open(shark)
                        }
                        .position(x: proxy.size.width * shark.mapX, y: proxy.size.height * shark.mapY)
                    }
                }
            }

            HStack(spacing: 24) {
                Label("\(game.completedCount) of 10 shark pages", systemImage: "book.closed.fill")
                Label("\(game.collectedWords.count) Ocean Words", systemImage: "text.book.closed.fill")
                Text(game.readingMode.title)
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(.black.opacity(0.16), in: Capsule())
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
    }

    private func headerButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(minHeight: 58)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white.opacity(0.18))
    }
}

private struct SharkMapNode: View {
    let shark: SharkDefinition
    let unlocked: Bool
    let action: () -> Void
    @State private var floating = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(unlocked ? shark.tint.gradient : Color.black.opacity(0.32).gradient)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(.white.opacity(unlocked ? 0.8 : 0.25), lineWidth: 3))
                    if unlocked {
                        SpeciesImageView(shark: shark)
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    } else {
                        Text("🔒").font(.system(size: 42))
                    }
                }
                Text(shark.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.38), in: Capsule())
            }
            .offset(y: floating ? -4 : 4)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.72)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0 + Double(abs(shark.id.hashValue % 5)) / 5).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
        .accessibilityLabel(unlocked ? "Explore the \(shark.name)" : "\(shark.name), locked")
    }
}

private struct WorldMapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let islands = [
            CGRect(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.22, width: rect.width * 0.22, height: rect.height * 0.45),
            CGRect(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.12, width: rect.width * 0.18, height: rect.height * 0.35),
            CGRect(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.22, width: rect.width * 0.18, height: rect.height * 0.46),
            CGRect(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.48, width: rect.width * 0.16, height: rect.height * 0.25)
        ]
        for island in islands { path.addRoundedRect(in: island, cornerSize: CGSize(width: 80, height: 80)) }
        return path
    }
}

struct ParentGateButton: View {
    let action: () -> Void
    @GestureState private var pressing = false

    var body: some View {
        Image(systemName: "gearshape.fill")
            .font(.title2)
            .frame(width: 60, height: 60)
            .background(pressing ? .orange.opacity(0.7) : .white.opacity(0.16), in: Circle())
            .contentShape(Circle())
            .gesture(LongPressGesture(minimumDuration: 2).updating($pressing) { value, state, _ in state = value }.onEnded { _ in action() })
            .accessibilityLabel("Parent settings. Press and hold.")
    }
}
