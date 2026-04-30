import SwiftUI

enum HiAirV2Theme {
    static var pageGradient: LinearGradient {
        TimeOfDayBackground.gradient()
    }

    static var cardFill: Color {
        TimeOfDayBackground.surfacePrimary().opacity(0.92)
    }

    static let cardStroke = AuroraTokens.ColorPalette.textPrimary.opacity(0.14)
    static let primaryText = AuroraTokens.ColorPalette.textPrimary
    static let secondaryText = AuroraTokens.ColorPalette.textSecondary
    static let tertiaryText = AuroraTokens.ColorPalette.textTertiary
    static let accentStart = AuroraTokens.ColorPalette.ctaStart
    static let accentEnd = AuroraTokens.ColorPalette.ctaEnd
}

struct V2Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AuroraTokens.Radius.lg)
                    .fill(HiAirV2Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AuroraTokens.Radius.lg)
                            .stroke(HiAirV2Theme.cardStroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func v2Card() -> some View {
        modifier(V2Card())
    }

    func v2PageBackground() -> some View {
        background(HiAirV2Theme.pageGradient.ignoresSafeArea())
    }
}

struct V2PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.16))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [HiAirV2Theme.accentStart, HiAirV2Theme.accentEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AuroraTokens.Radius.md))
            .shadow(
                color: Color(red: 0.23, green: 0.61, blue: 1.0).opacity(0.24),
                radius: 14,
                x: 0,
                y: 6
            )
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}
