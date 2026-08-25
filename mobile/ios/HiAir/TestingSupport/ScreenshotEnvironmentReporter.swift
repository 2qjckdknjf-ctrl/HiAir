import SwiftUI
import UIKit

/// Writes runtime-observed screenshot environment for capture pipeline verification.
enum ScreenshotEnvironmentReporter {
    struct Snapshot: Codable {
        let captureRunId: String
        let locale: String
        let contentSizeCategory: String
        let reduceMotionEnabled: Bool
        let reduceTransparencyEnabled: Bool
        let horizontalSizeClass: String
        let verticalSizeClass: String
        let userInterfaceIdiom: String
        let screenWidthPoints: Double
        let screenHeightPoints: Double
        let screenScale: Double
        let appVersion: String
        let appBuild: String
        let observedAt: String
    }

    private static func captureRunId() -> String? {
        let env = ProcessInfo.processInfo.environment
        return env["HIAIR_CAPTURE_RUN_ID"]
            ?? env["TEST_RUNNER_HIAIR_CAPTURE_RUN_ID"]
            ?? env["HIAIR_SCREENSHOT_RUN_STAMP"]
            ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_RUN_STAMP"]
    }

    private static func outputDirectory() -> String? {
        let env = ProcessInfo.processInfo.environment
        return env["HIAIR_SCREENSHOT_OUT"] ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_OUT"]
    }

    static func reportIfNeeded(from scene: UIWindowScene?) {
        guard UITestBootstrap.shouldReportShotEnvironment else { return }
        guard let runId = captureRunId(), !runId.isEmpty else { return }
        guard let out = outputDirectory(), !out.isEmpty else { return }

        let url = URL(fileURLWithPath: out, isDirectory: true)
            .appendingPathComponent("app-observed-environment.json")

        if let existing = try? Data(contentsOf: url),
           let prior = try? JSONDecoder().decode(Snapshot.self, from: existing),
           prior.captureRunId == runId {
            return
        }

        let traits = scene?.traitCollection ?? UITraitCollection.current
        let bounds = scene?.screen.bounds ?? UIScreen.main.bounds
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (info["CFBundleVersion"] as? String) ?? "unknown"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let snapshot = Snapshot(
            captureRunId: runId,
            locale: Locale.current.identifier,
            contentSizeCategory: UIApplication.shared.preferredContentSizeCategory.rawValue,
            reduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            reduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled,
            horizontalSizeClass: traits.horizontalSizeClass == .regular ? "regular" : "compact",
            verticalSizeClass: traits.verticalSizeClass == .regular ? "regular" : "compact",
            userInterfaceIdiom: traits.userInterfaceIdiom == .pad ? "pad" : "phone",
            screenWidthPoints: Double(bounds.width),
            screenHeightPoints: Double(bounds.height),
            screenScale: Double(scene?.screen.scale ?? UIScreen.main.scale),
            appVersion: version,
            appBuild: build,
            observedAt: formatter.string(from: Date())
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

struct ScreenshotEnvironmentReporterModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            guard UITestBootstrap.shouldReportShotEnvironment else { return }
            DispatchQueue.main.async {
                ScreenshotEnvironmentReporter.reportIfNeeded(
                    from: UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
                )
            }
        }
    }
}

extension View {
    func hiAirScreenshotEnvironmentReporter() -> some View {
        modifier(ScreenshotEnvironmentReporterModifier())
    }
}
