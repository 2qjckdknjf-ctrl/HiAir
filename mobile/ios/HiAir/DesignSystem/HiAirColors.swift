import SwiftUI

enum HiAirColors {
    enum Text {
        static let primary = Color(hex: 0xF0F4FF)
        static let secondary = Color(hex: 0xA8B5D1)
        static let tertiary = Color(hex: 0x6A7A99)
    }

    enum Cta {
        static let gradientStart = Color(hex: 0x5DD5C4)
        static let gradientEnd = Color(hex: 0x8B7BFF)
        static let labelOnGradient = Color(hex: 0x0D172A)
    }

    enum Risk {
        static let low = Color(hex: 0x7DDCB0)
        static let moderate = Color(hex: 0xF5B66E)
        static let high = Color(hex: 0xF08A8A)
        static let veryHigh = Color(hex: 0xC95684)
    }

    enum Feedback {
        static let info = Color(hex: 0x7BCBFF)
        static let errorSoft = Color(hex: 0xFF9AA2)
    }

    enum Overlay {
        static let subtle = Color.white.opacity(0.08)
        static let medium = Color.white.opacity(0.12)
        static let strong = Color.white.opacity(0.18)
        static let borderSoft = Color.white.opacity(0.14)
        static let borderGlass = Color.white.opacity(0.24)
        static let avatarHighlight = Color.white.opacity(0.78)
        static let avatarFeature = Color.white.opacity(0.80)
    }

    enum Brand {
        static let orbCyan = Color(hex: 0x5DD5C4)
        static let orbViolet = Color(hex: 0x8B7BFF)
        static let orbTeal = Color(hex: 0x3ECFB8)
    }
}
