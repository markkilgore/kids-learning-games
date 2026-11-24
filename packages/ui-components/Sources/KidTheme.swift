import LearningEngine
import SwiftUI

/// One app's colors and the shared shape scale every screen draws from.
public struct KidTheme: Sendable {
    public let background: [Color]
    public let primary: Color
    public let secondary: Color
    public let success: Color
    public let surface: Color
    /// Main text color on the app background.
    public let ink: Color
    public let isDark: Bool

    public init(tokens: ThemeTokens, ink: Color, isDark: Bool) {
        background = tokens.background.map { Color(hex: $0) }
        primary = Color(hex: tokens.primary)
        secondary = Color(hex: tokens.secondary)
        success = Color(hex: tokens.success)
        surface = Color(hex: tokens.surface)
        self.ink = ink
        self.isDark = isDark
    }

    public enum Radius {
        public static let small: CGFloat = 14
        public static let medium: CGFloat = 22
        public static let large: CGFloat = 30
    }

    /// Smallest comfortable touch target for a young child.
    public static let touchTarget: CGFloat = 64

    public var mutedInk: Color { ink.opacity(isDark ? 0.75 : 0.7) }

    public func cardFill(_ level: KidCardLevel) -> Color {
        switch (level, isDark) {
        case (.quiet, true): .white.opacity(0.08)
        case (.regular, true): .white.opacity(0.14)
        case (.raised, true): .white.opacity(0.2)
        case (.quiet, false): .white.opacity(0.6)
        case (.regular, false): .white.opacity(0.86)
        case (.raised, false): .white
        }
    }

    public var backdrop: LinearGradient {
        LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let fallback = KidTheme(
        tokens: ThemeTokens(background: ["#FFF4D6", "#FADADD"], primary: "#A855F7", secondary: "#F97316", success: "#22C55E", surface: "#FFF9EE"),
        ink: Color(hex: "#3B2A4A"),
        isDark: false
    )
}

public enum KidCardLevel: Sendable { case quiet, regular, raised }

private struct KidThemeKey: EnvironmentKey {
    static let defaultValue = KidTheme.fallback
}

public extension EnvironmentValues {
    var kidTheme: KidTheme {
        get { self[KidThemeKey.self] }
        set { self[KidThemeKey.self] = newValue }
    }
}

public extension Font {
    static let kidDisplay = Font.system(size: 38, weight: .black, design: .rounded)
    static let kidTitle = Font.system(size: 30, weight: .heavy, design: .rounded)
    static let kidHeadline = Font.system(size: 23, weight: .bold, design: .rounded)
    static let kidBody = Font.system(size: 20, weight: .medium, design: .rounded)
    static let kidLabel = Font.system(size: 17, weight: .semibold, design: .rounded)
}

private struct KidCard: ViewModifier {
    @Environment(\.kidTheme) private var theme
    let level: KidCardLevel
    let tint: Color?
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(tint.map { AnyShapeStyle($0.gradient) } ?? AnyShapeStyle(theme.cardFill(level)), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(theme.isDark ? 0.16 : 0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.1), radius: level == .quiet ? 0 : 10, y: level == .quiet ? 0 : 5)
    }
}

public extension View {
    /// The standard card surface: one fill scale, one corner scale, one soft shadow.
    func kidCard(_ level: KidCardLevel = .regular, tint: Color? = nil, radius: CGFloat = KidTheme.Radius.medium) -> some View {
        modifier(KidCard(level: level, tint: tint, radius: radius))
    }
}
