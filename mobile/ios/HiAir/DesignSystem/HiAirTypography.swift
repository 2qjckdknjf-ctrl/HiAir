import SwiftUI

enum HiAirTypography {
    static let displayXL = Font.system(size: 88, weight: .semibold, design: .rounded)
    static let displayLG = Font.system(size: 34, weight: .bold)
    static let titleLG = Font.system(size: 22, weight: .semibold)
    static let titleMD = Font.system(size: 17, weight: .semibold)
    static let bodyLG = Font.system(size: 17, weight: .regular)
    static let bodyMD = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .medium)

    static func scaled(_ base: Font, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        base
    }
}
