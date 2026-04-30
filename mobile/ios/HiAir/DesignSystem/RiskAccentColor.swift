import SwiftUI

enum RiskAccentColor {
    static func color(for riskLevel: String) -> Color {
        switch riskLevel.lowercased() {
        case "low":
            return AuroraTokens.ColorPalette.riskLow
        case "moderate", "medium":
            return AuroraTokens.ColorPalette.riskModerate
        case "high":
            return AuroraTokens.ColorPalette.riskHigh
        case "very_high", "very high":
            return AuroraTokens.ColorPalette.riskVeryHigh
        default:
            return AuroraTokens.ColorPalette.textSecondary
        }
    }
}
