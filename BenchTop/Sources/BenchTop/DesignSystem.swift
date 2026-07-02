import SwiftUI

/// Design tokens for BenchTop. Colors resolve from the asset catalog so
/// light/dark are *selected* variants, not runtime flips. See
/// docs/design/BenchTop-design.html for the full workup these encode.
enum Theme {
    enum Palette {
        static let ink = Color("Ink")
        static let surface = Color("Surface")
        static let elevated = Color("Elevated")
        static let hairline = Color("Hairline")

        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")

        /// Accent — "alive / now / active".
        static let signal = Color("Signal")
        /// Reserved for exactly one thing: the payoff (shortlist → wet lab → cure).
        static let gold = Color("Gold")

        static let statusDone = Color("StatusDone")
        static let statusFailed = Color("StatusFailed")
        static let statusWarning = Color("StatusWarning")
        static let statusIdle = Color("StatusIdle")

        /// Funnel ordinal ramp, broad → narrow (index 0…4). Validated for
        /// monotone lightness, step separation, and surface contrast.
        static let funnel: [Color] = [
            Color("Funnel1"), Color("Funnel2"), Color("Funnel3"),
            Color("Funnel4"), Color("Funnel5"),
        ]

        /// The colour for funnel stage `index` of `count` stages. The final
        /// stage is emphasised in gold — the emphasized endpoint; earlier
        /// stages walk the ordinal ramp broad → narrow.
        static func funnelColor(index: Int, count: Int) -> Color {
            if index == count - 1 { return gold }
            return funnel[min(index, funnel.count - 1)]
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 36
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
    }
}

extension Font {
    static let btDisplay = Font.system(size: 30, weight: .heavy, design: .default)
    static let btTitle = Font.system(size: 22, weight: .bold, design: .default)
    static let btHeadline = Font.system(size: 16, weight: .semibold, design: .default)
    static let btBody = Font.system(size: 15, weight: .regular, design: .default)
    static let btCaption = Font.system(size: 12, weight: .regular, design: .default)

    /// For every number — tabular monospaced, the telemetry voice.
    static func btData(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }
}

extension Text {
    /// Uppercase section label with tracking — the "eyebrow" from the workup.
    func btEyebrow() -> some View {
        self.font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(Theme.Palette.textTertiary)
    }
}

/// Standard card surface used throughout.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Space.l)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func btCard() -> some View { modifier(CardBackground()) }
}
