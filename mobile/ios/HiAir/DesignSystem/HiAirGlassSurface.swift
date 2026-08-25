import SwiftUI

enum HiAirGlassProminence: Equatable {
    case hero
    case active
    case standard
    case passive
    case compact

    var fillAlpha: Double {
        switch self {
        case .hero: return 0.90
        case .active: return 0.84
        case .standard: return 0.80
        case .passive: return 0.70
        case .compact: return 0.74
        }
    }

    var innerHighlight: Double {
        switch self {
        case .hero: return 0.28
        case .active: return 0.22
        case .standard: return 0.18
        case .passive: return 0.12
        case .compact: return 0.16
        }
    }

    var borderAlpha: Double {
        switch self {
        case .hero: return 0.88
        case .active: return 0.72
        case .standard: return 0.56
        case .passive: return 0.38
        case .compact: return 0.46
        }
    }

    var outerGlowAlpha: Double {
        switch self {
        case .hero: return 0.42
        case .active: return 0.30
        case .standard: return 0.20
        case .passive: return 0.12
        case .compact: return 0.16
        }
    }

    var blurRadius: CGFloat {
        switch self {
        case .hero: return 12
        case .active: return 10
        case .standard: return 8
        case .passive: return 7
        case .compact: return 7
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .hero: return HiAirRadius.hero
        case .active, .standard: return HiAirRadius.lg
        case .passive: return HiAirRadius.lg
        case .compact: return HiAirRadius.compact
        }
    }
}

struct HiAirGlassSurface: View {
    var prominence: HiAirGlassProminence = .standard
    var cornerRadius: CGFloat? = nil
    var glow: Color = HiAirColors.Spectrum.cyan
    var isPressed: Bool = false

    private var radius: CGFloat { cornerRadius ?? prominence.cornerRadius }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(HiAirColors.Surface.glassFill.opacity(prominence.fillAlpha))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(HiAirGradients.glassRefraction(prominence: prominence))
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(prominence.innerHighlight),
                                Color.white.opacity(0.02),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(HiAirColors.Overlay.innerBorder, lineWidth: 1)
                    .padding(1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(HiAirGradients.glassBorder().opacity(min(prominence.borderAlpha, 1)), lineWidth: 1.6)
            }
            .shadow(
                color: glow.opacity(prominence.outerGlowAlpha),
                radius: prominence.blurRadius,
                x: 0,
                y: HiAirShadow.glassYOffset
            )
            .shadow(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 8)
            .scaleEffect(isPressed ? HiAirMotion.pressScale : 1)
            .brightness(isPressed ? -0.04 : 0)
    }
}

private struct HiAirGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let prominence: HiAirGlassProminence
    let cornerRadius: CGFloat
    let glow: Color

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(HiAirColors.Surface.bg3.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(HiAirColors.Overlay.borderGlass.opacity(0.7), lineWidth: 1)
                    )
            } else {
                HiAirGlassSurface(
                    prominence: prominence,
                    cornerRadius: cornerRadius,
                    glow: glow
                )
            }
        }
    }
}

private struct HiAirMaterializeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .onAppear {
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(HiAirMotion.materialize) {
                        visible = true
                    }
                }
            }
    }
}

extension View {
    func hiAirGlassSurface(
        prominence: HiAirGlassProminence = .standard,
        cornerRadius: CGFloat? = nil,
        glow: Color = HiAirColors.Spectrum.cyan
    ) -> some View {
        modifier(
            HiAirGlassSurfaceModifier(
                prominence: prominence,
                cornerRadius: cornerRadius ?? prominence.cornerRadius,
                glow: glow
            )
        )
    }

    func hiAirLiquidGlass(
        cornerRadius: CGFloat = HiAirRadius.lg,
        variant: HiAirLiquidGlass.Variant = .regular
    ) -> some View {
        hiAirGlassSurface(
            prominence: variant.prominence,
            cornerRadius: cornerRadius,
            glow: HiAirColors.Spectrum.cyan
        )
    }

    func hiAirLiquidGlassNav(cornerRadius: CGFloat = HiAirRadius.xl) -> some View {
        hiAirGlassSurface(prominence: .active, cornerRadius: cornerRadius)
    }

    func hiAirLiquidGlassMaterialize() -> some View {
        modifier(HiAirMaterializeModifier())
    }
}
