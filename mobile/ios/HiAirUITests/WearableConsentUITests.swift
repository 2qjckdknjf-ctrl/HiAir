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

        app.tabBars.buttons.element(boundBy: 4).tap()
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
        app.tabBars.buttons.element(boundBy: 4).tap()
        let status = waitForIdentifier(app, "settings.wearables.status", timeout: 10)
        let label = status.label.lowercased()
        XCTAssertFalse(label.contains("connected"))
        XCTAssertTrue(
            label.contains("access allowed") || label.contains("consent inactive"),
            "EN authorized/inactive expected, got: \(status.label)"
        )
    }
}
