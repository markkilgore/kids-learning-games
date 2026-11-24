import UIKit
import Narration
import SwiftUI

public enum AnswerState: Sendable { case idle, correct, wrong, dimmed }

/// Side-to-side shake for a wrong answer.
public struct ShakeEffect: GeometryEffect {
    public var animatableData: CGFloat

    public init(shakes: Int) { animatableData = CGFloat(shakes) }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// An answer choice that shows whether it was right: green bounce, or a shake and a soft red edge.
public struct AnswerTile<Label: View>: View {
    private let state: AnswerState
    private let tint: Color?
    private let action: () -> Void
    private let label: Label
    @Environment(\.kidTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    public init(state: AnswerState, tint: Color? = nil, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.state = state
        self.tint = tint
        self.action = action
        self.label = label()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: KidTheme.Radius.medium, style: .continuous)
        Button(action: action) {
            label
                .foregroundStyle(state == .correct ? .white : theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(fill, in: shape)
                .overlay(shape.strokeBorder(border, lineWidth: state == .idle || state == .dimmed ? 2 : 5))
                .overlay(alignment: .topTrailing) {
                    if state == .correct {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
        .scaleEffect(state == .correct ? 1.06 : 1)
        .opacity(state == .dimmed ? 0.45 : 1)
        .modifier(ShakeEffect(shakes: shakes))
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: state)
        .onChange(of: state) { _, new in
            guard new == .wrong, !reduceMotion else { return }
            withAnimation(.linear(duration: 0.45)) { shakes += 1 }
        }
    }

    private var fill: AnyShapeStyle {
        switch state {
        case .correct: AnyShapeStyle(theme.success.gradient)
        case .wrong: AnyShapeStyle(theme.cardFill(.quiet))
        case .idle, .dimmed: AnyShapeStyle(tint.map { $0.opacity(theme.isDark ? 0.45 : 0.2) } ?? theme.cardFill(.raised))
        }
    }

    private var border: Color {
        switch state {
        case .correct: .white.opacity(0.9)
        case .wrong: Color(hex: "#F87171")
        case .idle, .dimmed: tint?.opacity(0.7) ?? .white.opacity(theme.isDark ? 0.25 : 0.8)
        }
    }
}

/// A burst of confetti over the whole screen. Place it in an overlay; it ignores touches.
public struct CelebrationView: View {
    private let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?

    /// Fires each time `trigger` changes to a new non-zero value.
    public init(trigger: Int) { self.trigger = trigger }

    private static let colors: [Color] = [.yellow, .pink, .mint, .orange, .cyan, .purple, .white]
    private static let duration = 2.6

    public var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let time = timeline.date.timeIntervalSince(start)
                guard time < Self.duration else { return }
                for index in 0..<90 {
                    let seed = Double(index)
                    let angle = (seed * 137.5).truncatingRemainder(dividingBy: 360) * .pi / 180
                    let speed = 260 + (seed * 53).truncatingRemainder(dividingBy: 420)
                    let x = size.width / 2 + cos(angle) * speed * time
                    let y = size.height * 0.42 + sin(angle) * speed * time * 0.7 + 520 * time * time
                    let side = 9 + (seed * 7).truncatingRemainder(dividingBy: 9)
                    var piece = context
                    piece.opacity = max(0, 1 - time / Self.duration)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(time * (4 + seed.truncatingRemainder(dividingBy: 5)) + seed))
                    let rect = CGRect(x: -side / 2, y: -side / 4, width: side, height: side / 2)
                    piece.fill(index % 3 == 0 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.colors[index % Self.colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, value in
            guard value != 0, !reduceMotion else { return }
            let began = Date()
            start = began
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.duration))
                if start == began { start = nil }
            }
        }
    }
}

/// A short banner that slides in from the top, for "you unlocked something" moments.
public struct KidToast: View {
    private let symbol: String
    private let text: String
    @Environment(\.kidTheme) private var theme

    public init(symbol: String, text: String) {
        self.symbol = symbol
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(symbol).font(.system(size: 34))
            Text(text).font(.kidHeadline).foregroundStyle(.white)
        }
        .padding(.horizontal, 26)
        .frame(minHeight: KidTheme.touchTarget)
        .background(theme.success.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

/// Emoji or bundled artwork: shows the named image when the app ships one, otherwise the emoji.
public struct KidArt: View {
    public enum Style: Sendable {
        /// A portrait painted on a plain background, cropped to a circle.
        case medallion
        /// A small square painting, shown whole with softly rounded corners.
        case tile
        /// A cut-out object on a transparent background, shown as is at about the emoji's size.
        case plain
    }

    private let asset: String
    private let fallback: String
    private let size: CGFloat
    private let style: Style

    public init(_ asset: String, fallback: String, size: CGFloat, style: Style = .medallion) {
        self.asset = asset
        self.fallback = fallback
        self.size = size
        self.style = style
    }

    public var body: some View {
        if let image = UIImage(named: asset) {
            switch style {
            case .medallion:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 1.45, height: size * 1.45)
                    .clipShape(Circle())
            case .tile:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 1.45, height: size * 1.45)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            case .plain:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 1.2, height: size * 1.2)
            }
        } else {
            Text(fallback).font(.system(size: size))
        }
    }
}
