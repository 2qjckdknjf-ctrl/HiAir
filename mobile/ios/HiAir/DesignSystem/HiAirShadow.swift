import SwiftUI

enum HiAirShadow {
    static let ctaGlow = HiAirColors.Spectrum.cyan.opacity(0.32)
    static let ctaRadius: CGFloat = 18
    static let ctaYOffset: CGFloat = 8

    static let glassBlur: CGFloat = 18
    static let glassYOffset: CGFloat = 10

    static func riskGlow(_ color: Color, intensity: Double = 0.3) -> Color {
        color.opacity(intensity)
    }

    static func glassGlow(for prominence: HiAirGlassProminence, accent: Color) -> Color {
        accent.opacity(prominence.outerGlowAlpha)
    }
}
