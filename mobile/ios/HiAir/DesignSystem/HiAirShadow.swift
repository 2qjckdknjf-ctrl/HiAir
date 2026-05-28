import SwiftUI

enum HiAirShadow {
    static let ctaGlow = Color(hex: 0x3B9CFF).opacity(0.24)
    static let ctaRadius: CGFloat = 14
    static let ctaYOffset: CGFloat = 6

    static func riskGlow(_ color: Color, intensity: Double = 0.3) -> Color {
        color.opacity(intensity)
    }
}
