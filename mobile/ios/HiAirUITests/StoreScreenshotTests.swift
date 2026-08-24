import XCTest
import UIKit

/// Captures App Store product screenshots into `HIAIR_SCREENSHOT_OUT` (PNG files).
/// Launch with UITEST_STORE_SHOTS=1 so the app installs rich mock API payloads.
final class StoreScreenshotTests: XCTestCase {
    func testCaptureStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let runStamp = env["HIAIR_SCREENSHOT_RUN_STAMP"]
            ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_RUN_STAMP"]
            ?? UUID().uuidString
        if !runStamp.isEmpty {
            UserDefaults.standard.set(runStamp, forKey: "HIAIR_SCREENSHOT_RUN_STAMP")
        }
        let outPath = env["HIAIR_SCREENSHOT_OUT"]
            ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_OUT"]
            ?? "\(FileManager.default.temporaryDirectory.path)/hiair-store-screenshots"
        let outURL = URL(fileURLWithPath: outPath, isDirectory: true)
        try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)

        let language = env["HIAIR_SHOT_LANGUAGE"] ?? env["TEST_RUNNER_HIAIR_SHOT_LANGUAGE"] ?? "en"
        let shotEnv: [String: String] = [
            "HIAIR_REPORT_SHOT_ENV": "1",
            "HIAIR_SCREENSHOT_OUT": outPath,
            "HIAIR_CAPTURE_RUN_ID": runStamp,
            "TEST_RUNNER_HIAIR_CAPTURE_RUN_ID": runStamp,
        ]

        // 1) Auth / marketing entry
        var app = UITestLaunch.launch(
            language: language,
            seedAuth: false,
            seedLocation: false,
            clearProfile: true,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: ["UITEST_STORE_SHOTS": "1"].merging(shotEnv) { _, new in new }
        )
        _ = waitForIdentifier(app, "auth.root", timeout: 12)
        sleepBriefly(1.2)
        try savePNG(app, to: outURL.appendingPathComponent("01-auth.png"))

        app.terminate()

        app = UITestLaunch.launch(
            language: language,
            seedAuth: true,
            seedLocation: false,
            clearProfile: true,
            skipOnboarding: false,
            mockAPI: true,
            extraEnvironment: [
                "UITEST_STORE_SHOTS": "1",
                "UITEST_EMAIL": "alex@hiair.io",
                "UITEST_USER_ID": "store-shot-user",
            ].merging(shotEnv) { _, new in new }
        )
        _ = waitForIdentifier(app, "onboarding.root", timeout: 12)
        sleepBriefly(1.2)
        try savePNG(app, to: outURL.appendingPathComponent("01b-onboarding.png"))
        app.terminate()

        // 2–6) Main tabs with seeded session + profile
        app = UITestLaunch.launch(
            language: language,
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: [
                "UITEST_STORE_SHOTS": "1",
                "UITEST_PROFILE_ID": "profile-uitest-1",
                "UITEST_PLACE_NAME": "Castelldefels",
                "UITEST_EMAIL": "alex@hiair.io",
                "UITEST_USER_ID": "store-shot-user",
            ].merging(shotEnv) { _, new in new }
        )
        _ = waitForIdentifier(app, "tab.dashboard", timeout: 12)
        sleepBriefly(2.0)
        try savePNG(app, to: outURL.appendingPathComponent("02-dashboard.png"))

        tapTabBar(app, identifier: "tab.planner")
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("03-planner.png"))

        tapTabBar(app, identifier: "tab.insights")
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("04-insights.png"))

        tapTabBar(app, identifier: "tab.symptoms")
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("05-symptoms.png"))

        tapTabBar(app, identifier: "tab.settings")
        sleepBriefly(1.5)
        try savePNG(app, to: outURL.appendingPathComponent("06-settings.png"))

        let paywall = app.descendants(matching: .any)["settings.open_paywall"]
        for _ in 0..<6 where !paywall.exists || !paywall.isHittable {
            app.swipeUp()
            sleepBriefly(0.35)
        }
        if paywall.waitForExistence(timeout: 3) {
            try savePNG(app, to: outURL.appendingPathComponent("06b-settings-subscription.png"))
            if paywall.isHittable {
                paywall.tap()
                _ = waitForIdentifier(app, "paywall.root", timeout: 8)
                sleepBriefly(6.0)
                assertNoRawPaywallKeys(in: app)
                try savePNG(app, to: outURL.appendingPathComponent("07-paywall.png"))
                app.swipeUp()
                sleepBriefly(0.8)
                try savePNG(app, to: outURL.appendingPathComponent("07b-paywall-restore.png"))
            }
        }

        try validateObservedEnvironment(outURL: outURL, language: language, runId: runStamp)
    }

    private func validateObservedEnvironment(outURL: URL, language: String, runId: String) throws {
        let requestedURL = outURL.appendingPathComponent("requested-environment.json")
        let env = ProcessInfo.processInfo.environment
        let a11y = env["HIAIR_SHOT_ACCESSIBILITY"] ?? env["TEST_RUNNER_HIAIR_SHOT_ACCESSIBILITY"] ?? "standard"
        let motion = env["HIAIR_SHOT_REDUCE_MOTION"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_MOTION"] ?? "system"
        let transparency = env["HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? "system"
        let requested: [String: Any] = [
            "captureRunId": runId,
            "language": language,
            "requestedAccessibilityTextSize": a11y,
            "requestedReduceMotion": motion,
            "requestedReduceTransparency": transparency,
        ]
        let requestedData = try JSONSerialization.data(withJSONObject: requested, options: [.prettyPrinted])
        try requestedData.write(to: requestedURL, options: .atomic)

        let observedURL = outURL.appendingPathComponent("app-observed-environment.json")
        for _ in 0..<30 {
            if FileManager.default.fileExists(atPath: observedURL.path) { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: observedURL.path),
            "App must write app-observed-environment.json from runtime"
        )
        let observedData = try Data(contentsOf: observedURL)
        let attachment = XCTAttachment(data: observedData, uniformTypeIdentifier: "public.json")
        attachment.name = "app-observed-environment"
        attachment.lifetime = .keepAlways
        add(attachment)

        let observed = try JSONSerialization.jsonObject(with: observedData) as? [String: Any]
        XCTAssertEqual(observed?["captureRunId"] as? String, runId)
        if let locale = observed?["locale"] as? String {
            XCTAssertTrue(locale.lowercased().hasPrefix(String(language.prefix(2)).lowercased()), "Unexpected locale \(locale)")
        }
        if a11y == "accessibility3" || a11y == "a11y3" {
            let cat = observed?["contentSizeCategory"] as? String ?? ""
            XCTAssertTrue(cat.contains("AccessibilityM"), "Expected AccessibilityM got \(cat)")
        } else if a11y == "accessibility5" || a11y == "a11y5" {
            let cat = observed?["contentSizeCategory"] as? String ?? ""
            XCTAssertTrue(cat.contains("AccessibilityXXXL"), "Expected AccessibilityXXXL got \(cat)")
        }
        if motion == "1" || motion.lowercased() == "true" {
            XCTAssertEqual(observed?["reduceMotionEnabled"] as? Bool, true)
        }
        if transparency == "1" || transparency.lowercased() == "true" {
            XCTAssertEqual(observed?["reduceTransparencyEnabled"] as? Bool, true)
        }
    }

    private func assertNoRawPaywallKeys(in app: XCUIApplication) {
        for element in app.staticTexts.allElementsBoundByIndex {
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(label.hasPrefix("paywall."), "Raw paywall localization key visible: \(label)")
        }
    }

    private func tapTabBar(_ app: XCUIApplication, identifier: String) {
        let tab = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 8), "Missing tab \(identifier)")
        tab.tap()
    }
}
