import SwiftUI

enum HiAirLayoutMode {
    case compact
    case standard
    case largePhone
    case tablet
}

enum HiAirScreenMetrics {
    static let compactMaxWidth: CGFloat = 375
    static let standardMaxWidth: CGFloat = 430
    static let tabletMinWidth: CGFloat = 600
    static let contentMaxWidth: CGFloat = 680

    static func layoutMode(for width: CGFloat) -> HiAirLayoutMode {
        if width >= tabletMinWidth { return .tablet }
        if width >= standardMaxWidth { return .largePhone }
        if width < compactMaxWidth { return .compact }
        return .standard
    }

    static func allowsTwoColumn(for width: CGFloat) -> Bool {
        width >= tabletMinWidth
    }

    static func heroOrbSize(for width: CGFloat) -> CGFloat {
        switch layoutMode(for: width) {
        case .compact: return min(width * 0.20, 72)
        case .standard: return min(width * 0.22, 96)
        case .largePhone: return min(width * 0.24, 112)
        case .tablet: return min(width * 0.16, 160)
        }
    }

    static func horizontalPadding(for width: CGFloat) -> CGFloat {
        switch layoutMode(for: width) {
        case .compact: return HiAirSpacing.md
        case .standard: return HiAirSpacing.md
        case .largePhone: return HiAirSpacing.lg
        case .tablet: return HiAirSpacing.xl
        }
    }
}

struct HiAirAdaptiveLayout<Content: View>: View {
    @ViewBuilder let content: (CGFloat, HiAirLayoutMode) -> Content

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mode = HiAirScreenMetrics.layoutMode(for: width)
            content(width, mode)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct HiAirContentWidthModifier: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: HiAirScreenMetrics.contentMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func hiAirContentWidth(for width: CGFloat) -> some View {
        modifier(HiAirContentWidthModifier(width: width))
    }

    func hiAirScreenPadding(for width: CGFloat) -> some View {
        padding(.horizontal, HiAirScreenMetrics.horizontalPadding(for: width))
    }
}
