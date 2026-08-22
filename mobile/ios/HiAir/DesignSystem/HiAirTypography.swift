import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum HiAirTypography {
    static let displayXL = scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
    static let displayLG = scaledFont(size: 32, weight: .bold, relativeTo: .title)
    static let titleLG = scaledFont(size: 22, weight: .semibold, relativeTo: .title2)
    static let titleMD = scaledFont(size: 18, weight: .semibold, relativeTo: .headline)
    static let bodyLG = scaledFont(size: 17, weight: .medium, relativeTo: .body)
    static let bodyMD = scaledFont(size: 15, weight: .medium, relativeTo: .subheadline)
    static let caption = scaledFont(size: 13, weight: .semibold, relativeTo: .caption)

    static func scaled(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        scaledFont(size: size, weight: weight, design: design, relativeTo: textStyle)
    }

    private static func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        #if canImport(UIKit)
        let metrics = UIFontMetrics(forTextStyle: textStyle.uiKitTextStyle)
        let scaledSize = metrics.scaledValue(for: size)
        return Font.system(size: scaledSize, weight: weight, design: design)
        #else
        return Font.system(size: size, weight: weight, design: design)
        #endif
    }
}

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
