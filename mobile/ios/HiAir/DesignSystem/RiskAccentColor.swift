import SwiftUI

enum RiskAccentColor {
    static func color(for riskLevel: String) -> Color {
        HiAirRiskStyle.color(for: riskLevel)
    }
}
