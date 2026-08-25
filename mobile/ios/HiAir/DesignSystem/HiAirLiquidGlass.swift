import SwiftUI

/// Deep Glass variant map. Prefer `hiAirGlassSurface`; this type remains for existing call sites.
enum HiAirLiquidGlass {
    enum Variant {
        case regular
        case clear
        case identity

        var prominence: HiAirGlassProminence {
            switch self {
            case .regular: return .standard
            case .clear: return .passive
            case .identity: return .passive
            }
        }
    }

    static func material(for variant: Variant) -> Material {
        switch variant {
        case .regular:
            return .thinMaterial
        case .clear:
            return .ultraThinMaterial
        case .identity:
            return .regularMaterial
        }
    }
}
