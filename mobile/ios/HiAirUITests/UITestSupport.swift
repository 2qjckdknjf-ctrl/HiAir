import XCTest

/// Shared launch helpers for Simulator UI integrity suite.
enum UITestLaunch {
    static let defaultTimeout: TimeInterval = 8

    static func launch(
        language: String = "ru",
        seedAuth: Bool = true,
        seedLocation: Bool = true,
        clearProfile: Bool = true,
        skipOnboarding: Bool = true,
        mockAPI: Bool = true,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-UITestLanguage=\(language)",
        ]
        if skipOnboarding {
            app.launchArguments.append("-UITestSkipOnboarding")
        }
        if mockAPI {
            app.launchArguments.append("-UITestMockAPI")
        }

        applyShotAccessibilityLaunchArguments(to: &app.launchArguments)

        if language.lowercased().hasPrefix("ru") {
            app.launchArguments.append("-AppleLanguages")
            app.launchArguments.append("(ru)")
            app.launchArguments.append("-AppleLocale")
            app.launchArguments.append("ru_RU")
        } else {
            app.launchArguments.append("-AppleLanguages")
            app.launchArguments.append("(en)")
            app.launchArguments.append("-AppleLocale")
            app.launchArguments.append("en_US")
        }

        var env: [String: String] = [:]
        if seedAuth {
            env["UITEST_SEED_AUTH"] = "1"
            env["UITEST_USER_ID"] = "uitest-user"
            env["UITEST_EMAIL"] = "uitest@example.com"
            env["UITEST_ACCESS_TOKEN"] = "uitest-access-token"
            env["UITEST_REFRESH_TOKEN"] = ""
        }
        if seedLocation {
            env["UITEST_SEED_LOCATION"] = "1"
            env["UITEST_LAT"] = "41.2800"
            env["UITEST_LON"] = "1.9760"
            env["UITEST_PLACE_NAME"] = "Castelldefels"
        }
        if clearProfile {
            env["UITEST_CLEAR_PROFILE"] = "1"
            env["UITEST_DISABLE_AUTO_PROFILE"] = "1"
        }
        if !seedLocation {
            env["UITEST_DISABLE_AUTO_PROFILE"] = "1"
        }
        for (key, value) in extraEnvironment {
            env[key] = value
        }
        app.launchEnvironment = env
        app.launch()
        return app
    }

    private static func applyShotAccessibilityLaunchArguments(to launchArguments: inout [String]) {
        let env = ProcessInfo.processInfo.environment
        let accessibility = env["HIAIR_SHOT_ACCESSIBILITY"] ?? env["TEST_RUNNER_HIAIR_SHOT_ACCESSIBILITY"] ?? "standard"
        let reduceMotion = env["HIAIR_SHOT_REDUCE_MOTION"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_MOTION"] ?? "system"
        let reduceTransparency = env["HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? env["TEST_RUNNER_HIAIR_SHOT_REDUCE_TRANSPARENCY"] ?? "system"

        let contentSizeCategory: String? = switch accessibility.lowercased() {
        case "accessibility3", "a11y3": "UICTContentSizeCategoryAccessibilityM"
        case "accessibility5", "a11y5": "UICTContentSizeCategoryAccessibilityXXXL"
        case "standard", "large": "UICTContentSizeCategoryLarge"
        default: nil
        }
        if let contentSizeCategory {
            launchArguments.append("-UIPreferredContentSizeCategoryName=\(contentSizeCategory)")
        }
        if reduceMotion == "1" || reduceMotion.lowercased() == "true" {
            launchArguments.append("-UIAccessibilityReduceMotionEnabled")
            launchArguments.append("YES")
        }
        if reduceTransparency == "1" || reduceTransparency.lowercased() == "true" {
            launchArguments.append("-UIAccessibilityReduceTransparencyEnabled")
            launchArguments.append("YES")
        }
    }

    static func saveEvidence(app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        // Caller XCTestCase attaches via Thread? — use global store via notification is awkward.
        // Attachments must be added from XCTestCase; helpers return attachment for caller.
        _ = attachment
    }
}

extension XCTestCase {
    func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func attachA11yDump(_ app: XCUIApplication, name: String) {
        let dump = app.debugDescription
        let attachment = XCTAttachment(string: dump)
        attachment.name = "\(name)-a11y"
        attachment.lifetime = .keepAlways
        add(attachment)

        let evidenceRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hiair-ui-integrity", isDirectory: true)
        try? FileManager.default.createDirectory(at: evidenceRoot, withIntermediateDirectories: true)
        let file = evidenceRoot.appendingPathComponent("\(name).txt")
        try? dump.write(to: file, atomically: true, encoding: .utf8)
    }

    @discardableResult
    func waitForIdentifier(_ app: XCUIApplication, _ identifier: String, timeout: TimeInterval = UITestLaunch.defaultTimeout) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing accessibility id: \(identifier)")
        return element
    }

    func sleepBriefly(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    func savePNG(_ app: XCUIApplication, to url: URL) throws {
        let data = app.screenshot().pngRepresentation
        try data.write(to: url, options: .atomic)
        attachScreenshot(app, name: url.deletingPathExtension().lastPathComponent)
    }

    func tapHiAirTab(_ app: XCUIApplication, identifier: String, timeout: TimeInterval = UITestLaunch.defaultTimeout) {
        let tab = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Missing tab: \(identifier)")
        tab.tap()
    }

    @discardableResult
    func scrollToIdentifier(
        _ app: XCUIApplication,
        _ identifier: String,
        timeout: TimeInterval = 12
    ) -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                return element
            }
            app.swipeUp(velocity: .fast)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(element.waitForExistence(timeout: 1), "Missing accessibility id after scroll: \(identifier)")
        if !element.isHittable {
            app.swipeDown(velocity: .slow)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element
    }
}
