import SwiftUI

enum TimeOfDayBackground {
    static func gradient(for date: Date = Date()) -> LinearGradient {
        LinearGradient(
            colors: [
                HiAirColors.Surface.bg0,
                TimeOfDayPhase.from(date: date).colors.last ?? HiAirColors.Surface.bg2,
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func surfacePrimary(for date: Date = Date()) -> Color {
        _ = date
        return HiAirColors.Surface.bg2
    }

    static func surfaceSecondary(for date: Date = Date()) -> Color {
        _ = date
        return HiAirColors.Surface.bg3
    }

    static func surfaceElevated(for date: Date = Date()) -> Color {
        _ = date
        return HiAirColors.Surface.bg3.lightened(by: 0.08)
    }
}
