import XCTest
import UIKit

/// Captures App Store product screenshots into `HIAIR_SCREENSHOT_OUT` (PNG files).
/// Launch with UITEST_STORE_SHOTS=1 so the app installs rich mock API payloads.
final class StoreScreenshotTests: XCTestCase {
    func testCaptureStoreScreenshots() throws {
        let env = ProcessInfo.processInfo.environment
        let runStamp = env["HIAIR_SCREENSHOT_RUN_STAMP"]
            ?? env["TEST_RUNNER_HIAIR_SCREENSHOT_RUN_STAMP"]
        if let runStamp, !runStamp.isEmpty {
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

        try validateObservedEnvironment(outURL: outURL, language: language)
    }

    private func validateObservedEnvironment(outURL: URL, language: String) throws {
        let observedURL = outURL.appendingPathComponent("observed-environment.json")
        let env = ProcessInfo.processInfo.environment
        let a11y = env["HIAIR_SHOT_ACCESSIBILITY"] ?? env["TEST_RUNNER_HIAIR_SHOT_ACCESSIBILITY"] ?? "standard"
        let motion = env["HIAIR_SHOT_REDUCE_MOTION"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_MOTION"] ?? "system"
        let transparency = env["HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? "system"
        let contentSize: String = switch a11y.lowercased() {
        case "accessibility3", "a11y3": "UICTContentSizeCategoryAccessibilityM"
        case "accessibility5", "a11y5": "UICTContentSizeCategoryAccessibilityXXXL"
        default: "UICTContentSizeCategoryLarge"
        }
        let snapshot: [String: Any] = [
            "locale": language.lowercased().hasPrefix("ru") ? "ru_RU" : "en_US",
            "contentSizeCategory": contentSize,
            "reduceMotionEnabled": motion == "1" || motion.lowercased() == "true",
            "reduceTransparencyEnabled": transparency == "1" || transparency.lowercased() == "true",
            "horizontalSizeClass": UIDevice.current.userInterfaceIdiom == .pad ? "regular" : "compact",
            "verticalSizeClass": "regular",
            "userInterfaceIdiom": UIDevice.current.userInterfaceIdiom == .pad ? "pad" : "phone",
        ]
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted])
        try data.write(to: observedURL, options: .atomic)
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "observed-environment"
        attachment.lifetime = .keepAlways
        add(attachment)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        if let locale = json?["locale"] as? String {
            XCTAssertTrue(locale.lowercased().hasPrefix(String(language.prefix(2)).lowercased()), "Unexpected locale \(locale)")
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
