import SwiftUI

enum HiAirRiskStyle {
    static func color(for riskLevel: String) -> Color {
        switch riskLevel.lowercased() {
        case "low":
            return HiAirColors.Risk.low
        case "moderate", "medium":
            return HiAirColors.Risk.moderate
        case "high":
            return HiAirColors.Risk.high
        case "very_high", "very high":
            return HiAirColors.Risk.veryHigh
        default:
            return HiAirColors.Text.secondary
        }
    }

    static func orbPulseDuration(for riskLevel: String) -> Double {
        switch riskLevel.lowercased() {
        case "low":
            return HiAirMotion.orbPulseLow
        case "moderate", "medium":
            return HiAirMotion.orbPulseModerate
        case "high":
            return HiAirMotion.orbPulseHigh
        case "very_high", "very high":
            return HiAirMotion.orbPulseVeryHigh
        default:
            return HiAirMotion.orbPulseLow
        }
    }

    static func badgeFill(for riskLevel: String) -> Color {
        color(for: riskLevel).opacity(0.2)
    }
}
