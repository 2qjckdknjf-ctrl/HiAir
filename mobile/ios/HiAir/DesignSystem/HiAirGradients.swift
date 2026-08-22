import SwiftUI

enum HiAirGradients {
    static func cta() -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Cta.gradientStart,
                HiAirColors.Cta.gradientMid,
                HiAirColors.Cta.gradientEnd,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func ctaDiagonal() -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Cta.gradientStart,
                HiAirColors.Cta.gradientMid,
                HiAirColors.Cta.gradientEnd,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func spectral() -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Spectrum.cyan,
                HiAirColors.Spectrum.electricBlue,
                HiAirColors.Spectrum.violet,
                HiAirColors.Spectrum.magenta,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func good() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Spectrum.cyan, HiAirColors.Risk.low],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func moderate() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Risk.moderate, HiAirColors.Risk.high],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func severe() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Risk.high, HiAirColors.Risk.veryHigh, HiAirColors.Spectrum.magenta],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glassRefraction(prominence: HiAirGlassProminence) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(prominence.innerHighlight),
                HiAirColors.Spectrum.cyan.opacity(prominence.fillAlpha * 0.22),
                HiAirColors.Spectrum.violet.opacity(prominence.fillAlpha * 0.18),
                Color.black.opacity(0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glassBorder() -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Spectrum.cyan.opacity(0.95),
                Color.white.opacity(0.42),
                HiAirColors.Spectrum.violet.opacity(0.78),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func timeOfDay(for date: Date = Date()) -> LinearGradient {
        TimeOfDayBackground.gradient(for: date)
    }

    static func orbGlow(riskColor: Color) -> RadialGradient {
        RadialGradient(
            colors: [riskColor.opacity(0.85), HiAirColors.Spectrum.electricBlue.opacity(0.32)],
            center: .center,
            startRadius: 6,
            endRadius: 42
        )
    }

    static func launchBackground() -> LinearGradient {
        LinearGradient(
            colors: [HiAirColors.Surface.bg0, HiAirColors.Surface.bg2],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func atmosphericBase() -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Surface.bg0,
                HiAirColors.Surface.bg1,
                HiAirColors.Surface.bg2,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
