import SwiftUI
import UIKit

enum AuroraTokens {
    enum ColorPalette {
        static let textPrimary = Color(hex: 0xF0F4FF)
        static let textSecondary = Color(hex: 0xA8B5D1)
        static let textTertiary = Color(hex: 0x6A7A99)
        static let ctaStart = Color(hex: 0x5DD5C4)
        static let ctaEnd = Color(hex: 0x8B7BFF)
        static let riskLow = Color(hex: 0x7DDCB0)
        static let riskModerate = Color(hex: 0xF5B66E)
        static let riskHigh = Color(hex: 0xF08A8A)
        static let riskVeryHigh = Color(hex: 0xC95684)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
        static let hero: CGFloat = 64
    }

    enum Radius {
        static let pill: CGFloat = 999
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Motion {
        static let fast: Double = 0.24
        static let normal: Double = 0.32
        static let heroMorph: Double = 0.8
    }

    enum Typography {
        static let displayXL = Font.system(size: 88, weight: .semibold, design: .rounded)
        static let displayLG = Font.system(size: 34, weight: .bold)
        static let titleLG = Font.system(size: 22, weight: .semibold)
        static let titleMD = Font.system(size: 17, weight: .semibold)
        static let bodyLG = Font.system(size: 17, weight: .regular)
        static let bodyMD = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)
    }
}

enum TimeOfDayPhase {
    case dawn
    case morning
    case midday
    case afternoon
    case evening
    case night

    static func from(date: Date = Date(), calendar: Calendar = .current) -> TimeOfDayPhase {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<8:
            return .dawn
        case 8..<12:
            return .morning
        case 12..<16:
            return .midday
        case 16..<19:
            return .afternoon
        case 19..<22:
            return .evening
        default:
            return .night
        }
    }

    var colors: [Color] {
        switch self {
        case .dawn:
            return [Color(hex: 0x1A1530), Color(hex: 0x2B2050)]
        case .morning:
            return [Color(hex: 0x1B2845), Color(hex: 0x2A4373)]
        case .midday:
            return [Color(hex: 0x1F3260), Color(hex: 0x2E4A8A)]
        case .afternoon:
            return [Color(hex: 0x2A2547), Color(hex: 0x3D2F5C)]
        case .evening:
            return [Color(hex: 0x1A1A35), Color(hex: 0x25193D)]
        case .night:
            return [Color(hex: 0x0E1226), Color(hex: 0x181D38)]
        }
    }
}

extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    func lightened(by percent: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        let adjustedBrightness = min(brightness + percent, 1.0)
        return Color(uiColor: UIColor(hue: hue, saturation: saturation, brightness: adjustedBrightness, alpha: alpha))
    }
}
