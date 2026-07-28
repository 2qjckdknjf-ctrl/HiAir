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
}
