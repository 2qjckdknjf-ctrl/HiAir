import SwiftUI
import UIKit

/// Writes observed screenshot environment for capture pipeline verification.
enum ScreenshotEnvironmentReporter {
    struct Snapshot: Codable {
        let locale: String
        let contentSizeCategory: String
        let reduceMotionEnabled: Bool
        let reduceTransparencyEnabled: Bool
        let horizontalSizeClass: String
        let verticalSizeClass: String
        let userInterfaceIdiom: String
    }

    static func reportIfNeeded(from scene: UIWindowScene?) {
        guard UITestBootstrap.shouldReportShotEnvironment else { return }
        let out = ProcessInfo.processInfo.environment["HIAIR_SCREENSHOT_OUT"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_HIAIR_SCREENSHOT_OUT"]
        guard let out, !out.isEmpty else { return }

        let url = URL(fileURLWithPath: out, isDirectory: true).appendingPathComponent("observed-environment.json")
        if FileManager.default.fileExists(atPath: url.path) { return }

        let traits = scene?.traitCollection ?? UITraitCollection.current
        let snapshot = Snapshot(
            locale: Locale.current.identifier,
            contentSizeCategory: UIApplication.shared.preferredContentSizeCategory.rawValue,
            reduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            reduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled,
            horizontalSizeClass: traits.horizontalSizeClass == .regular ? "regular" : "compact",
            verticalSizeClass: traits.verticalSizeClass == .regular ? "regular" : "compact",
            userInterfaceIdiom: traits.userInterfaceIdiom == .pad ? "pad" : "phone"
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct ScreenshotEnvironmentReporterModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.onAppear {
            guard UITestBootstrap.shouldReportShotEnvironment else { return }
            DispatchQueue.main.async {
                ScreenshotEnvironmentReporter.reportIfNeeded(from: UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            }
        }
    }
}

extension View {
    func hiAirScreenshotEnvironmentReporter() -> some View {
        modifier(ScreenshotEnvironmentReporterModifier())
    }
}
