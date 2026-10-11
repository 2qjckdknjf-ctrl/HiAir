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

    /// Deep Glass navy family with a slight time-of-day bias — never a light sky.
    var colors: [Color] {
        switch self {
        case .dawn:
            return [HiAirColors.Surface.bg0, Color(hex: 0x16102C)]
        case .morning:
            return [HiAirColors.Surface.bg0, HiAirColors.Surface.bg2]
        case .midday:
            return [HiAirColors.Surface.bg1, Color(hex: 0x10244A)]
        case .afternoon:
            return [HiAirColors.Surface.bg0, Color(hex: 0x14142E)]
        case .evening:
            return [HiAirColors.Surface.bg0, Color(hex: 0x120E28)]
        case .night:
            return [HiAirColors.Surface.bg0, HiAirColors.Surface.bg1]
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
