import SwiftUI

enum HiAirResponsiveSpacing {
    static func cardSpacing(for mode: HiAirLayoutMode) -> CGFloat {
        switch mode {
        case .compact: return HiAirSpacing.sm
        case .standard: return HiAirSpacing.md
        case .largePhone: return HiAirSpacing.lg
        case .tablet: return HiAirSpacing.lg
        }
    }

    static func sectionSpacing(for mode: HiAirLayoutMode) -> CGFloat {
        switch mode {
        case .compact: return HiAirSpacing.md
        case .standard: return HiAirSpacing.md
        case .largePhone: return HiAirSpacing.lg
        case .tablet: return HiAirSpacing.xl
        }
    }

    static func heroTopPadding(for mode: HiAirLayoutMode) -> CGFloat {
        switch mode {
        case .compact: return HiAirSpacing.xs
        case .standard: return HiAirSpacing.sm
        case .largePhone: return HiAirSpacing.md
        case .tablet: return HiAirSpacing.lg
        }
    }
}
