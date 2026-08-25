import SwiftUI

enum HiAirTypography {
    static let displayXL = Font.system(size: 64, weight: .bold, design: .rounded)
    static let displayLG = Font.system(size: 32, weight: .bold)
    static let titleLG = Font.system(size: 22, weight: .semibold)
    static let titleMD = Font.system(size: 18, weight: .semibold)
    static let bodyLG = Font.system(size: 17, weight: .medium)
    static let bodyMD = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .semibold)

    static func scaled(_ base: Font, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        base
    }
}
