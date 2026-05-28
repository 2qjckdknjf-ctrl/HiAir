import SwiftUI

enum HiAirGradients {
    static func cta() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Cta.gradientStart, HiAirColors.Cta.gradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func ctaDiagonal() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Cta.gradientStart, HiAirColors.Cta.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func timeOfDay(for date: Date = Date()) -> LinearGradient {
        TimeOfDayBackground.gradient(for: date)
    }

    static func orbGlow(riskColor: Color) -> RadialGradient {
        RadialGradient(
            colors: [riskColor.opacity(0.85), HiAirColors.Feedback.info.opacity(0.32)],
            center: .center,
            startRadius: 6,
            endRadius: 42
        )
    }

    static func launchBackground() -> LinearGradient {
        LinearGradient(
            colors: TimeOfDayPhase.night.colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
