import LearningUI
import Narration
import SwiftUI
import UIKit

struct OceanMapView: View {
    @Environment(GameStore.self) private var game
    @Environment(NarrationCoordinator.self) private var narration
    @Environment(FeedbackPlayer.self) private var feedback
    @Environment(\.kidTheme) private var theme
    @State private var lockedHint: SharkDefinition?
    /// The ocean on screen; remembered so the map reopens where it was left.
    @AppStorage("map.page") private var pageID = ""
    private let catalog = ContentStore.shared.catalog

    var body: some View {
        VStack(spacing: 12) {
            KidTopBar(SharkAppConfiguration.value.identity.childFacingName, subtitle: "Tap a shark to dive in") {
                WeeklyLessonsButton(resource: "shark-weeks", namespace: SharkAppConfiguration.value.storageNamespace, guide: "🦈", color: theme.primary)
                Button { game.showBooks() } label: { Label("My Books", systemImage: "books.vertical.fill") }
                    .buttonStyle(KidButtonStyle(.soft, compact: true))
                    .accessibilityIdentifier("my-books")
                ParentGateButton { game.destination = .settings }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            if catalog.mapPages.count > 1 {
                KidTabs(selection: $pageID, items: catalog.mapPages.map { .init($0.id, $0.name, systemImage: $0.symbol) })
                    .frame(maxWidth: 860)
            }

            // Swipe sideways, or tap a tab, to move between oceans.
            TabView(selection: $pageID) {
                ForEach(catalog.mapPages) { page in
                    GeometryReader { proxy in
                        ZStack {
                            OceanMapArt(page: page).padding(.horizontal, 24).padding(.vertical, 6)

                            ForEach(catalog.sharks(on: page)) { shark in
                                SharkMapNode(
                                    shark: shark,
                                    unlocked: game.isUnlocked(shark),
                                    completed: game.completedSharks.contains(shark.id),
                                    stars: game.stars(for: shark),
                                    fresh: game.freshlyUnlockedSharkIDs.contains(shark.id)
                                ) {
                                    if game.isUnlocked(shark) { game.open(shark) } else { showLockedHint(for: shark) }
                                }
                                .scaleEffect(1.2)
                                .position(x: proxy.size.width * shark.mapX, y: proxy.size.height * shark.mapY)
                            }
                        }
                    }
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 18) {
                Label("\(game.completedCount) of \(catalog.sharks.count) shark pages", systemImage: "book.closed.fill")
                Label("\(game.totalStars) stars", systemImage: "star.fill")
                if game.totalSuperStars > 0 { Label("\(game.totalSuperStars) super", systemImage: "sparkles").foregroundStyle(.cyan) }
                ProgressView(value: Double(game.completedCount), total: Double(max(catalog.sharks.count, 1)))
                    .tint(.yellow)
                    .frame(width: 180)
                    .scaleEffect(y: 2.4)
                Label("\(game.collectedWords.count) Ocean Words", systemImage: "text.book.closed.fill")
            }
            .font(.kidLabel)
            .padding(.horizontal, 26)
            .frame(height: 52)
            .background(.black.opacity(0.22), in: Capsule())
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) {
            if let lockedHint {
                let needed = game.missionsNeeded(for: lockedHint), stars = game.starsNeeded(for: lockedHint), superStars = game.superStarsNeeded(for: lockedHint)
                KidToast(symbol: needed > 0 ? "🔒" : stars > 0 ? "⭐️" : "🌟", text: needed > 0
                    ? "Finish \(needed) more shark \(needed == 1 ? "mission" : "missions") to find this shark"
                    : stars > 0
                    ? "Earn \(stars) more \(stars == 1 ? "star" : "stars") to find this shark"
                    : "Earn \(superStars) more super \(superStars == 1 ? "star" : "stars") to find this shark")
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            // Open on the ocean with a newly found shark, else where the map was left.
            let fresh = catalog.sharks.first { game.freshlyUnlockedSharkIDs.contains($0.id) }?.map
            if let fresh, catalog.mapPages.contains(where: { $0.id == fresh }) {
                pageID = fresh
            } else if !catalog.mapPages.contains(where: { $0.id == pageID }) {
                pageID = catalog.mapPages[0].id
            }
        }
        .task {
            guard !game.freshlyUnlockedSharkIDs.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(500))
            feedback.play(.unlock)
            narration.play(SharkLine.newShark.text, after: 1.0)
        }
        .onDisappear {
            // Stop only the map's own hints; the next screen may already be speaking.
            if [SharkLine.newShark.text, SharkLine.locked.text, SharkLine.lockedStars.text, SharkLine.lockedSuperStars.text].contains(narration.text) { narration.stop() }
        }
    }

    private func showLockedHint(for shark: SharkDefinition) {
        feedback.play(.wrong)
        let line: SharkLine = game.missionsNeeded(for: shark) > 0 ? .locked : game.starsNeeded(for: shark) > 0 ? .lockedStars : .lockedSuperStars
        narration.play(line.text, after: 0.5)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { lockedHint = shark }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if lockedHint == shark { withAnimation { lockedHint = nil } }
        }
    }
}

private struct SharkMapNode: View {
    let shark: SharkDefinition
    let unlocked: Bool
    let completed: Bool
    let stars: Int
    let fresh: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false
    @State private var pulsing = false
    @State private var wiggles = 0

    var body: some View {
        Button {
            if !unlocked, !reduceMotion { withAnimation(.linear(duration: 0.45)) { wiggles += 1 } }
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if fresh {
                        Circle()
                            .stroke(.yellow, lineWidth: 5)
                            .frame(width: 82, height: 82)
                            .scaleEffect(pulsing ? 1.35 : 1)
                            .opacity(pulsing ? 0 : 0.9)
                    }
                    Circle()
                        .fill(unlocked ? AnyShapeStyle(shark.tint.gradient) : AnyShapeStyle(Color.black.opacity(0.4)))
                        .frame(width: 78, height: 78)
                        .overlay(Circle().strokeBorder(.white.opacity(unlocked ? 0.9 : 0.3), lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 5)
                    if unlocked {
                        SpeciesImageView(shark: shark)
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .overlay(alignment: .top) {
                    if completed {
                        MissionStars(count: stars, size: 12)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .offset(y: -10)
                            .accessibilityHidden(true)
                    }
                }
                Text(unlocked ? shark.name : "Hidden shark")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
            }
            .offset(y: floating ? -4 : 4)
        }
        .buttonStyle(PressableStyle())
        .modifier(ShakeEffect(shakes: wiggles))
        .opacity(unlocked ? 1 : 0.8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.0 + Double(shark.name.count % 5) / 5).repeatForever(autoreverses: true)) { floating = true }
            if fresh { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulsing = true } }
        }
        .accessibilityLabel(unlocked ? "Explore the \(shark.name)\(completed ? ", \(stars) of \(MissionChallenges.maxLevel) stars" : "")" : "Hidden shark, locked")
        .accessibilityIdentifier("shark-\(shark.id)")
    }
}

/// The world behind the shark markers: bundled artwork when present, otherwise drawn continents.
private struct OceanMapArt: View {
    let page: MapPage

    var body: some View {
        // Each page can have its own picture (`map-pacific.jpg`); the shared world map stands in until it does.
        if let image = UIImage(named: "map-\(page.id).jpg") ?? UIImage(named: "ocean-map") {
            Color.clear
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KidTheme.Radius.large, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 2))
                .accessibilityHidden(true)
        } else {
            Canvas { context, size in
                // Each continent is a cluster of overlapping blobs, placed as fractions of the map.
                let continents: [[(x: Double, y: Double, w: Double, h: Double)]] = [
                    [(0.16, 0.30, 0.20, 0.30), (0.22, 0.44, 0.12, 0.20), (0.25, 0.68, 0.10, 0.34)],
                    [(0.50, 0.24, 0.14, 0.20), (0.52, 0.54, 0.15, 0.42)],
                    [(0.70, 0.28, 0.30, 0.30), (0.74, 0.46, 0.14, 0.18)],
                    [(0.84, 0.74, 0.14, 0.16)]
                ]
                for blobs in continents {
                    var land = Path()
                    for blob in blobs {
                        land.addEllipse(in: CGRect(x: (blob.x - blob.w / 2) * size.width, y: (blob.y - blob.h / 2) * size.height, width: blob.w * size.width, height: blob.h * size.height))
                    }
                    context.fill(land, with: .color(Color(hex: "#7FE3B5").opacity(0.2)))
                    context.stroke(land, with: .color(.white.opacity(0.12)), lineWidth: 2)
                }
                for row in 1..<4 {
                    var wave = Path()
                    let y = size.height * Double(row) / 4
                    wave.move(to: CGPoint(x: 0, y: y))
                    for step in 1...24 {
                        let x = size.width * Double(step) / 24
                        wave.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - size.width / 48, y: y + (step.isMultiple(of: 2) ? 7 : -7)))
                    }
                    context.stroke(wave, with: .color(.white.opacity(0.07)), style: StrokeStyle(lineWidth: 2, dash: [10, 14]))
                }
            }
            .accessibilityHidden(true)
        }
    }
}
