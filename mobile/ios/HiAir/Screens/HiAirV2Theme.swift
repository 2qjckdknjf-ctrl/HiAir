import SwiftUI

enum HiAirV2Theme {
    static var pageGradient: LinearGradient {
        HiAirGradients.timeOfDay()
    }

    static var cardFill: Color {
        TimeOfDayBackground.surfacePrimary().opacity(0.92)
    }

    static let cardStroke = HiAirColors.Overlay.borderSoft
    static let primaryText = HiAirColors.Text.primary
    static let secondaryText = HiAirColors.Text.secondary
    static let tertiaryText = HiAirColors.Text.tertiary
    static let accentStart = HiAirColors.Cta.gradientStart
    static let accentEnd = HiAirColors.Cta.gradientEnd
}

struct V2Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HiAirSpacing.md)
            .hiAirGlassSurface(prominence: .standard, cornerRadius: HiAirRadius.lg)
    }
}

extension View {
    func v2Card() -> some View {
        modifier(V2Card())
    }

    func v2PageBackground() -> some View {
        background {
            HiAirAtmosphericBackground()
                .ignoresSafeArea()
        }
    }
}

struct V2PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HiAirGradientButtonStyle().makeBody(configuration: configuration)
    }
}

typealias AuroraTokens = HiAirLegacyTokens

enum HiAirLegacyTokens {
    enum ColorPalette {
        static let textPrimary = HiAirColors.Text.primary
        static let textSecondary = HiAirColors.Text.secondary
        static let textTertiary = HiAirColors.Text.tertiary
        static let ctaStart = HiAirColors.Cta.gradientStart
        static let ctaEnd = HiAirColors.Cta.gradientEnd
        static let info = HiAirColors.Feedback.info
        static let errorSoft = HiAirColors.Feedback.errorSoft
        static let riskLow = HiAirColors.Risk.low
        static let riskModerate = HiAirColors.Risk.moderate
        static let riskHigh = HiAirColors.Risk.high
        static let riskVeryHigh = HiAirColors.Risk.veryHigh
    }

    enum Spacing {
        static let xxs = HiAirSpacing.xxs
        static let xs = HiAirSpacing.xs
        static let sm = HiAirSpacing.sm
        static let md = HiAirSpacing.md
        static let lg = HiAirSpacing.lg
        static let xl = HiAirSpacing.xl
        static let xxl = HiAirSpacing.xxl
        static let xxxl = HiAirSpacing.xxxl
        static let hero = HiAirSpacing.hero
    }

    enum Radius {
        static let pill = HiAirRadius.pill
        static let sm = HiAirRadius.sm
        static let md = HiAirRadius.md
        static let lg = HiAirRadius.lg
        static let xl = HiAirRadius.xl
    }

    enum Motion {
        static let fast = HiAirMotion.fast
        static let normal = HiAirMotion.normal
        static let heroMorph = HiAirMotion.heroMorph
    }

    enum Typography {
        static let displayXL = HiAirTypography.displayXL
        static let displayLG = HiAirTypography.displayLG
        static let titleLG = HiAirTypography.titleLG
        static let titleMD = HiAirTypography.titleMD
        static let bodyLG = HiAirTypography.bodyLG
        static let bodyMD = HiAirTypography.bodyMD
        static let caption = HiAirTypography.caption
    }
}
