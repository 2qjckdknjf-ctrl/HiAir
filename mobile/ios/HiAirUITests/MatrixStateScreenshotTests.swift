import XCTest

/// Captures dashboard/settings matrix states (loading, empty, error, offline, account deletion recovery).
final class MatrixStateScreenshotTests: XCTestCase {
    private var outURL: URL!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        let outPath = env["HIAIR_SCREENSHOT_OUT"]
            ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_OUT"]
            ?? "\(FileManager.default.temporaryDirectory.path)/hiair-matrix-states"
        outURL = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
    }

    private func shotEnv(extra: [String: String] = [:]) -> [String: String] {
        [
            "HIAIR_REPORT_SHOT_ENV": "1",
            "HIAIR_SCREENSHOT_OUT": outURL.path,
        ].merging(extra) { _, new in new }
    }

    func testCaptureDashboardLoading() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_MATRIX_STATE": "loading",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "tab.dashboard", timeout: 12)
        sleepBriefly(0.8)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-dashboard-loading.png"))
        app.terminate()
    }

    func testCaptureDashboardEmpty() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: false,
            clearProfile: true,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_MATRIX_STATE": "empty",
                "UITEST_DISABLE_AUTO_PROFILE": "1",
            ])
        )
        _ = waitForIdentifier(app, "tab.dashboard", timeout: 12)
        sleepBriefly(1.2)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-dashboard-empty.png"))
        app.terminate()
    }

    func testCaptureDashboardError() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_MATRIX_STATE": "error",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "tab.dashboard", timeout: 12)
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-dashboard-error.png"))
        app.terminate()
    }

    func testCaptureDashboardOfflineStale() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_MATRIX_STATE": "offline",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "tab.dashboard", timeout: 12)
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-dashboard-offline.png"))
        app.terminate()
    }

    func testCaptureAccountDeletionRecovery() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_SELECTED_TAB": "4",
                "UITEST_SEED_ACCOUNT_DELETION_RECOVERY": "1",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "settings.root", timeout: 12)
        sleepBriefly(1.0)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-settings-account-deletion-recovery.png"))
        app.terminate()
    }

    func testCaptureInsightsSuccess() throws {
        let language = ProcessInfo.processInfo.environment["HIAIR_SHOT_LANGUAGE"] ?? "en"
        let app = UITestLaunch.launch(
            language: language,
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_STORE_SHOTS": "1",
                "UITEST_SELECTED_TAB": "2",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "tab.insights", timeout: 12)
        tapTabBar(app, identifier: "tab.insights")
        let primary = app.descendants(matching: .any)["insights.primary.ready"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "Insights success must expose primary ready marker before capture")
        let partialBanner = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "haven’t updated")).firstMatch
        XCTAssertFalse(partialBanner.exists, "Success capture must not show partial banner")
        sleepBriefly(0.8)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-insights-success.png"))
        app.terminate()
    }

    func testCaptureInsightsPartial() throws {
        let language = ProcessInfo.processInfo.environment["HIAIR_SHOT_LANGUAGE"] ?? "en"
        let app = UITestLaunch.launch(
            language: language,
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: shotEnv(extra: [
                "UITEST_STORE_SHOTS": "1",
                "UITEST_MATRIX_STATE": "insights_partial",
                "UITEST_SELECTED_TAB": "2",
                "UITEST_PROFILE_ID": "profile-uitest-1",
            ])
        )
        _ = waitForIdentifier(app, "tab.insights", timeout: 12)
        tapTabBar(app, identifier: "tab.insights")
        let primary = app.descendants(matching: .any)["insights.primary.ready"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10), "Partial insights must keep primary content")
        let partial = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "haven’t updated")).firstMatch
        XCTAssertTrue(partial.waitForExistence(timeout: 8), "Partial banner must be visible before capture")
        let retry = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "Try again")).firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 4), "Partial retry CTA must be visible before capture")
        sleepBriefly(0.8)
        try savePNG(app, to: outURL.appendingPathComponent("matrix-insights-partial.png"))
        app.terminate()
    }

    private func tapTabBar(_ app: XCUIApplication, identifier: String) {
        let tab = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(identifier)")
        tab.tap()
    }
}
