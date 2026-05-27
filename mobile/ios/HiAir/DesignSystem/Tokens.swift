import SwiftUI
import UIKit

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
