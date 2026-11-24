import Narration
import SwiftUI

/// Large rounded button with a springy press and a tap sound.
public struct KidButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case filled, soft }

    private let kind: Kind
    private let tint: Color?
    private let compact: Bool

    public init(_ kind: Kind = .filled, tint: Color? = nil, compact: Bool = false) {
        self.kind = kind
        self.tint = tint
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        ButtonChrome(configuration: configuration, kind: kind, tint: tint, compact: compact)
    }
}

/// Press feedback for cards and tiles that draw their own surface.
public struct PressableStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressChrome(configuration: configuration)
    }
}

/// The one way out of a screen: same place, same size, in both apps.
public struct KidBackButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ title: String = "Home", systemImage: String = "house.fill", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) { Label(title, systemImage: systemImage) }
            .buttonStyle(KidButtonStyle(.soft, compact: true))
            .accessibilityIdentifier("kid-back")
    }
}

/// Back button on the left, title beside it, optional controls on the right.
public struct KidTopBar<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let back: KidBackButton?
    private let trailing: Trailing
    @Environment(\.kidTheme) private var theme

    public init(_ title: String, subtitle: String? = nil, back: KidBackButton? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.back = back
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 16) {
            back.fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kidDisplay)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(.kidLabel)
                        .foregroundStyle(theme.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(theme.ink)
            .layoutPriority(1)
            Spacer(minLength: 8)
            trailing
        }
    }
}

/// Two or three big tabs, used where a small segmented control would be hard to hit.
public struct KidTabs<ID: Hashable>: View {
    public struct Item {
        let id: ID
        let title: String
        let systemImage: String

        public init(_ id: ID, _ title: String, systemImage: String) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
        }
    }

    @Binding private var selection: ID
    private let items: [Item]
    @Environment(\.kidTheme) private var theme
    @Environment(FeedbackPlayer.self) private var feedback: FeedbackPlayer?

    public init(selection: Binding<ID>, items: [Item]) {
        _selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.id) { item in
                let selected = item.id == selection
                Button {
                    feedback?.play(.tap)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = item.id }
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                        .font(.kidHeadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(selected ? .white : theme.ink)
                        .padding(.horizontal, 22)
                        .frame(minHeight: KidTheme.touchTarget - 8)
                        .frame(maxWidth: .infinity)
                        .background(selected ? AnyShapeStyle(theme.primary.gradient) : AnyShapeStyle(.clear), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(theme.cardFill(.regular), in: Capsule())
    }
}

/// Opens grown-up settings after a two-second hold, with a ring showing the hold filling up.
public struct ParentGateButton: View {
    private let action: () -> Void
    @Environment(\.kidTheme) private var theme
    @State private var holding = false

    public init(action: @escaping () -> Void) { self.action = action }

    public var body: some View {
        Image(systemName: "gearshape.fill")
            .font(.title2)
            .foregroundStyle(theme.ink)
            .frame(width: KidTheme.touchTarget, height: KidTheme.touchTarget)
            .background(theme.cardFill(.regular), in: Circle())
            .overlay {
                Circle()
                    .trim(from: 0, to: holding ? 1 : 0)
                    .stroke(theme.secondary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(holding ? .linear(duration: 2) : .easeOut(duration: 0.2), value: holding)
            }
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 2) {
                holding = false
                action()
            } onPressingChanged: { holding = $0 }
            .accessibilityLabel("Parent settings. Press and hold.")
            .accessibilityIdentifier("parent-gate")
    }
}

private struct ButtonChrome: View {
    let configuration: ButtonStyleConfiguration
    let kind: KidButtonStyle.Kind
    let tint: Color?
    let compact: Bool
    @Environment(\.kidTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(FeedbackPlayer.self) private var feedback: FeedbackPlayer?

    var body: some View {
        let color = tint ?? theme.primary
        let soft = theme.isDark ? Color.white.opacity(0.18) : color.opacity(0.16)
        configuration.label
            .font(.kidHeadline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(kind == .filled ? Color.white : (theme.isDark ? .white : color))
            .padding(.horizontal, compact ? 18 : 26)
            .frame(minWidth: KidTheme.touchTarget, minHeight: KidTheme.touchTarget)
            .background(kind == .filled ? AnyShapeStyle(color.gradient) : AnyShapeStyle(soft), in: Capsule())
            .shadow(color: .black.opacity(kind == .filled ? 0.2 : 0), radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 4)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { feedback?.play(.tap) }
            }
    }
}

private struct PressChrome: View {
    let configuration: ButtonStyleConfiguration
    @Environment(FeedbackPlayer.self) private var feedback: FeedbackPlayer?

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { feedback?.play(.tap) }
            }
    }
}
