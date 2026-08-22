import UIKit

enum HiAirHaptics {
    static func tabChange() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func chipSelect() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func primaryAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
