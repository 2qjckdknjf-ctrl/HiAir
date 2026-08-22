import SwiftUI

enum HiAirColors {
    enum Surface {
        static let bg0 = Color(hex: 0x050B16)
        static let bg1 = Color(hex: 0x081221)
        static let bg2 = Color(hex: 0x0B1730)
        static let bg3 = Color(hex: 0x101B37)
        static let glassFill = Color(hex: 0x0B1730)
    }

    enum Text {
        static let primary = Color(hex: 0xFFFFFF)
        static let secondary = Color(hex: 0xE4ECF8)
        static let tertiary = Color(hex: 0xC5D4EC)
    }

    enum Cta {
        static let gradientStart = Color(hex: 0x1AE8FF)
        static let gradientMid = Color(hex: 0x4D8CFF)
        static let gradientEnd = Color(hex: 0xA06AFF)
        static let labelOnGradient = Color(hex: 0xFFFFFF)
    }

    enum Spectrum {
        static let cyan = Color(hex: 0x1AE8FF)
        static let electricBlue = Color(hex: 0x4D8CFF)
        static let violet = Color(hex: 0xA06AFF)
        static let magenta = Color(hex: 0xE05CFF)
    }

    enum Risk {
        static let low = Color(hex: 0x35E6A2)
        static let moderate = Color(hex: 0xFFD447)
        static let high = Color(hex: 0xFF8A3D)
        static let veryHigh = Color(hex: 0xFF4D68)
    }

    enum Feedback {
        static let info = Color(hex: 0x21D7FF)
        static let errorSoft = Color(hex: 0xFF4D68)
    }

    enum Overlay {
        static let subtle = Color.white.opacity(0.12)
        static let medium = Color.white.opacity(0.18)
        static let strong = Color.white.opacity(0.26)
        static let borderSoft = Color(hex: 0x1AE8FF).opacity(0.42)
        static let borderGlass = Color(hex: 0xA06AFF).opacity(0.46)
        static let avatarHighlight = Color.white.opacity(0.88)
        static let avatarFeature = Color.white.opacity(0.90)
        static let specular = Color.white.opacity(0.28)
        static let innerBorder = Color.white.opacity(0.34)
    }

    enum Brand {
        static let orbCyan = Color(hex: 0x1AE8FF)
        static let orbViolet = Color(hex: 0xA06AFF)
        static let orbTeal = Color(hex: 0x35E6A2)
        static let orbMagenta = Color(hex: 0xE05CFF)
    }
}
