import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum HiAirFontStyle {
    case displayXL
    case displayLG
    case titleLG
    case titleMD
    case bodyLG
    case bodyMD
    case caption

    var baseSize: CGFloat {
        switch self {
        case .displayXL: return 64
        case .displayLG: return 32
        case .titleLG: return 22
        case .titleMD: return 18
        case .bodyLG: return 17
        case .bodyMD: return 15
        case .caption: return 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .displayXL: return .bold
        case .displayLG: return .bold
        case .titleLG: return .semibold
        case .titleMD: return .semibold
        case .bodyLG: return .medium
        case .bodyMD: return .medium
        case .caption: return .semibold
        }
    }

    var design: Font.Design {
        switch self {
        case .displayXL: return .rounded
        default: return .default
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .displayXL: return .largeTitle
        case .displayLG: return .title
        case .titleLG: return .title2
        case .titleMD: return .headline
        case .bodyLG: return .body
        case .bodyMD: return .subheadline
        case .caption: return .caption
        }
    }
}

enum HiAirTypography {
    static func font(_ style: HiAirFontStyle, sizeCategory: ContentSizeCategory) -> Font {
        #if canImport(UIKit)
        let scaledSize = scaledFontSize(
            baseSize: style.baseSize,
            textStyle: style.uiKitTextStyle,
            sizeCategory: sizeCategory
        )
        return Font.system(size: scaledSize, weight: style.weight, design: style.design)
        #else
        return Font.system(size: style.baseSize, weight: style.weight, design: style.design)
        #endif
    }

    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body,
        sizeCategory: ContentSizeCategory
    ) -> Font {
        #if canImport(UIKit)
        let scaledSize = scaledFontSize(
            baseSize: size,
            textStyle: textStyle.uiKitTextStyle,
            sizeCategory: sizeCategory
        )
        return Font.system(size: scaledSize, weight: weight, design: design)
        #else
        return Font.system(size: size, weight: weight, design: design)
        #endif
    }
}

private struct HiAirFontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory
    let style: HiAirFontStyle

    func body(content: Content) -> some View {
        content.font(HiAirTypography.font(style, sizeCategory: sizeCategory))
    }
}

extension View {
    func hiAirFont(_ style: HiAirFontStyle) -> some View {
        modifier(HiAirFontModifier(style: style))
    }
}

extension HiAirTypography {
    static var displayXL: Font { font(.displayXL, sizeCategory: .medium) }
    static var displayLG: Font { font(.displayLG, sizeCategory: .medium) }
    static var titleLG: Font { font(.titleLG, sizeCategory: .medium) }
    static var titleMD: Font { font(.titleMD, sizeCategory: .medium) }
    static var bodyLG: Font { font(.bodyLG, sizeCategory: .medium) }
    static var bodyMD: Font { font(.bodyMD, sizeCategory: .medium) }
    static var caption: Font { font(.caption, sizeCategory: .medium) }

    #if DEBUG
    static func scaledPointSize(
        for style: HiAirFontStyle,
        sizeCategory: ContentSizeCategory
    ) -> CGFloat {
        #if canImport(UIKit)
        return scaledFontSize(
            baseSize: style.baseSize,
            textStyle: style.uiKitTextStyle,
            sizeCategory: sizeCategory
        )
        #else
        return style.baseSize
        #endif
    }
    #endif
}

#if canImport(UIKit)
private extension Font.TextStyle {
    var uiKitTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

private extension HiAirFontStyle {
    var uiKitTextStyle: UIFont.TextStyle { textStyle.uiKitTextStyle }
}

private extension ContentSizeCategory {
    var uiKitCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .medium
        }
    }
}

private func scaledFontSize(
    baseSize: CGFloat,
    textStyle: UIFont.TextStyle,
    sizeCategory: ContentSizeCategory
) -> CGFloat {
    let metrics = UIFontMetrics(forTextStyle: textStyle)
    let traits = UITraitCollection(preferredContentSizeCategory: sizeCategory.uiKitCategory)
    return metrics.scaledValue(for: baseSize, compatibleWith: traits)
}
#endif
