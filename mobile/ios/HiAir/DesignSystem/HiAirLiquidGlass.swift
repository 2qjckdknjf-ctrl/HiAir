import SwiftUI

/// Liquid Glass navigation-layer material (iOS 16+ `.material` fallback; denser tint on busy backgrounds).
enum HiAirLiquidGlass {
    enum Variant {
        case regular
        case clear
        case identity
    }

    enum Tint {
        static let regularLight = Color.white.opacity(0.14)
        static let regularDark = Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.38)
        static let clearLight = Color.white.opacity(0.08)
        static let sheen = Color.white.opacity(0.22)
        static let stroke = Color.white.opacity(0.26)
    }

    static func tint(for variant: Variant, colorScheme: ColorScheme) -> Color {
        switch variant {
        case .regular:
            return colorScheme == .dark ? Tint.regularDark : Tint.regularLight
        case .clear:
            return Tint.clearLight
        case .identity:
            return .clear
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

    @ViewBuilder
    static func backdrop(
        cornerRadius: CGFloat,
        variant: Variant = .regular,
        colorScheme: ColorScheme
    ) -> some View {
        if variant == .identity {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(TimeOfDayBackground.surfaceElevated().opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(HiAirColors.Overlay.borderSoft, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material(for: variant))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint(for: variant, colorScheme: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Tint.sheen, Tint.stroke.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
}

private struct HiAirLiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let cornerRadius: CGFloat
    let variant: HiAirLiquidGlass.Variant

    func body(content: Content) -> some View {
        content.background {
            if reduceTransparency {
                HiAirLiquidGlass.backdrop(
                    cornerRadius: cornerRadius,
                    variant: .identity,
                    colorScheme: colorScheme
                )
            } else {
                HiAirLiquidGlass.backdrop(
                    cornerRadius: cornerRadius,
                    variant: variant,
                    colorScheme: colorScheme
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
            .scaleEffect(visible ? 1 : (reduceMotion ? 1 : 0.94))
            .blur(radius: visible || reduceMotion ? 0 : 6)
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
    func hiAirLiquidGlass(
        cornerRadius: CGFloat = HiAirRadius.lg,
        variant: HiAirLiquidGlass.Variant = .regular
    ) -> some View {
        modifier(HiAirLiquidGlassModifier(cornerRadius: cornerRadius, variant: variant))
    }

    func hiAirLiquidGlassNav(cornerRadius: CGFloat = HiAirRadius.xl) -> some View {
        hiAirLiquidGlass(cornerRadius: cornerRadius, variant: .regular)
    }

    func hiAirLiquidGlassMaterialize() -> some View {
        modifier(HiAirMaterializeModifier())
    }
}
