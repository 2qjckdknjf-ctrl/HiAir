import SwiftUI

enum TimeOfDayBackground {
    static func gradient(for date: Date = Date()) -> LinearGradient {
        let phase = TimeOfDayPhase.from(date: date)
        return LinearGradient(
            colors: phase.colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func surfacePrimary(for date: Date = Date()) -> Color {
        let base = TimeOfDayPhase.from(date: date).colors.first ?? Color.black
        return base.lightened(by: 0.06)
    }

    static func surfaceSecondary(for date: Date = Date()) -> Color {
        let base = TimeOfDayPhase.from(date: date).colors.first ?? Color.black
        return base.lightened(by: 0.12)
    }

    static func surfaceElevated(for date: Date = Date()) -> Color {
        let base = TimeOfDayPhase.from(date: date).colors.first ?? Color.black
        return base.lightened(by: 0.18)
    }
}
