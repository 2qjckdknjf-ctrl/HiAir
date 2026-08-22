import XCTest

/// TF167 Simulator harness: OS HealthKit auth retained + account consent missing
/// must not render account-connected/«подключено» in Wearables settings.
final class WearableConsentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWearablesShowsAuthorizedNotConnectedWhenConsentMissing() throws {
        let app = UITestLaunch.launch(
            language: "ru",
            clearProfile: false,
            extraEnvironment: [
                "UITEST_PROFILE_ID": "profile-seed",
                "UITEST_CLEAR_PROFILE": "0",
                "UITEST_SEED_WEARABLE_OS_AUTH_NO_CONSENT": "1",
                "UITEST_SEED_STALE_CONNECTED": "1",
            ]
        )

        tapHiAirTab(app, identifier: "tab.settings")
        scrollToIdentifier(app, "settings.wearables.title")
        let wearablesTitle = waitForIdentifier(app, "settings.wearables.title", timeout: 10)
        XCTAssertTrue(wearablesTitle.exists)

        let status = waitForIdentifier(app, "settings.wearables.status", timeout: 8)
        attachScreenshot(app, name: "tf167-wearables-consent-missing")
        attachA11yDump(app, name: "tf167-wearables-consent-missing")

        let label = status.label.lowercased()
        XCTAssertFalse(
            label.contains("подключено") || label.contains("connected"),
            "Wearables must not show account-connected when consent is missing: \(status.label)"
        )
        XCTAssertTrue(
            label.contains("доступ разрешён")
                || label.contains("access allowed")
                || label.contains("согласие неактивно")
                || label.contains("consent inactive"),
            "Expected authorized/inactive presentation, got: \(status.label)"
        )
        XCTAssertTrue(app.descendants(matching: .any)["settings.wearables.connect"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.wearables.disconnect"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.wearables.delete"].exists)
    }

    func testWearablesAuthorizedNotConnectedInEnglish() throws {
        let app = UITestLaunch.launch(
            language: "en",
            clearProfile: false,
            extraEnvironment: [
                "UITEST_PROFILE_ID": "profile-seed",
                "UITEST_CLEAR_PROFILE": "0",
                "UITEST_SEED_WEARABLE_OS_AUTH_NO_CONSENT": "1",
                "UITEST_SEED_STALE_CONNECTED": "1",
            ]
        )
        tapHiAirTab(app, identifier: "tab.settings")
        scrollToIdentifier(app, "settings.wearables.title")
        let status = waitForIdentifier(app, "settings.wearables.status", timeout: 10)
        let label = status.label.lowercased()
        XCTAssertFalse(label.contains("connected"))
        XCTAssertTrue(
            label.contains("access allowed") || label.contains("consent inactive"),
            "EN authorized/inactive expected, got: \(status.label)"
        )
    }

    func testWearablesShowsConsentInactiveNotConnectedRU() throws {
        let app = UITestLaunch.launch(
            language: "ru",
            clearProfile: false,
            extraEnvironment: [
                "UITEST_PROFILE_ID": "profile-seed",
                "UITEST_CLEAR_PROFILE": "0",
                "UITEST_SEED_WEARABLE_DURABLE_INACTIVE": "1",
            ]
        )
        tapHiAirTab(app, identifier: "tab.settings")
        scrollToIdentifier(app, "settings.wearables.title")
        let status = waitForIdentifier(app, "settings.wearables.status", timeout: 10)
        attachScreenshot(app, name: "tf171-wearables-durable-inactive-ru")
        attachA11yDump(app, name: "tf171-wearables-durable-inactive-ru")

        let label = status.label.lowercased()
        XCTAssertTrue(status.exists)
        XCTAssertTrue(
            label.contains("согласие неактивно"),
            "Expected inactive-consent copy, got: \(status.label)"
        )
        XCTAssertFalse(
            label.contains("подключено") || label.contains("connected"),
            "Inactive durable consent must not show connected: \(status.label)"
        )
        let connect = app.descendants(matching: .any)["settings.wearables.connect"]
        let disconnect = app.descendants(matching: .any)["settings.wearables.disconnect"]
        let delete = app.descendants(matching: .any)["settings.wearables.delete"]
        XCTAssertTrue(connect.waitForExistence(timeout: 3))
        XCTAssertTrue(disconnect.exists)
        XCTAssertTrue(delete.exists)
        // Disconnect must remain a distinct control from Delete (labels + identifiers).
        XCTAssertNotEqual(disconnect.label, delete.label)
        XCTAssertNotEqual(
            disconnect.identifier.isEmpty ? "settings.wearables.disconnect" : disconnect.identifier,
            delete.identifier.isEmpty ? "settings.wearables.delete" : delete.identifier
        )
    }

    func testWearablesShowsConsentInactiveNotConnectedEN() throws {
        let app = UITestLaunch.launch(
            language: "en",
            clearProfile: false,
            extraEnvironment: [
                "UITEST_PROFILE_ID": "profile-seed",
                "UITEST_CLEAR_PROFILE": "0",
                "UITEST_SEED_WEARABLE_DURABLE_INACTIVE": "1",
            ]
        )
        tapHiAirTab(app, identifier: "tab.settings")
        scrollToIdentifier(app, "settings.wearables.title")
        let status = waitForIdentifier(app, "settings.wearables.status", timeout: 10)
        attachScreenshot(app, name: "tf171-wearables-durable-inactive-en")
        attachA11yDump(app, name: "tf171-wearables-durable-inactive-en")

        let label = status.label.lowercased()
        XCTAssertTrue(
            label.contains("consent inactive"),
            "Expected EN inactive-consent copy, got: \(status.label)"
        )
        XCTAssertFalse(label.contains("connected"))
        XCTAssertTrue(app.descendants(matching: .any)["settings.wearables.connect"].exists)
        let disconnect = app.descendants(matching: .any)["settings.wearables.disconnect"]
        let delete = app.descendants(matching: .any)["settings.wearables.delete"]
        XCTAssertTrue(disconnect.exists)
        XCTAssertTrue(delete.exists)
        XCTAssertNotEqual(disconnect.label, delete.label)
    }
}
