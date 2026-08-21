import StoreKitTest
import XCTest

/// iPad Air 11" (M3) Simulator purchase path — same device class as App Review 2.1(b).
/// Owner has no physical iPad: certification is StoreKit Testing on this simulator
/// (scheme StoreKit config + SKTestSession.disableDialogs), not ASC Sandbox/TestFlight.
final class IPadSandboxPurchaseUITests: XCTestCase {
    private var storeSession: SKTestSession?

    override func setUpWithError() throws {
        continueAfterFailure = false
        let configURL =
            Bundle(for: Self.self).url(forResource: "HiAirPremium", withExtension: "storekit")
            ?? URL(fileURLWithPath: "/Users/alex/Projects/HIAir/mobile/ios/HiAir/Configuration/HiAirPremium.storekit")
        let session = try SKTestSession(contentsOf: configURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        storeSession = session
    }

    override func tearDownWithError() throws {
        storeSession?.clearTransactions()
        storeSession = nil
    }

    func testIPadMonthlyPurchaseUnlocksPremium() throws {
        try runPurchase(productButtonID: "paywall.subscribe_monthly", shotPrefix: "ipad-monthly")
    }

    func testIPadYearlyPurchaseUnlocksPremium() throws {
        try runPurchase(productButtonID: "paywall.subscribe_yearly", shotPrefix: "ipad-yearly")
    }

    private func runPurchase(productButtonID: String, shotPrefix: String) throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: [
                "UITEST_PROFILE_ID": "profile-ipad-sandbox-1",
                "UITEST_PLACE_NAME": "Castelldefels",
                "UITEST_EMAIL": "ipad-sandbox@hiair.io",
                "UITEST_SELECTED_TAB": "4",
            ]
        )

        let settingsRoot = app.descendants(matching: .any)["settings.root"]
        if !settingsRoot.waitForExistence(timeout: 12) {
            app.descendants(matching: .any)["tab.settings"].tap()
        }
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 10), "Settings missing on iPad")
        attachScreenshot(app, name: "\(shotPrefix)-01-settings")

        let openPaywall = scrollToOpenPaywall(app)
        openPaywall.tap()
        let paywall = app.descendants(matching: .any)["paywall.root"]
        XCTAssertTrue(paywall.waitForExistence(timeout: 10), "Paywall fullScreenCover missing on iPad")
        let legal = app.descendants(matching: .any)["paywall.legal_copy"]
        XCTAssertTrue(legal.waitForExistence(timeout: 8), "3.1.2 facts card missing")
        XCTAssertTrue(
            app.descendants(matching: .any)["paywall.length_monthly"].waitForExistence(timeout: 8)
                || app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "1 month")).firstMatch.exists,
            "Monthly length missing on iPad paywall"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["paywall.length_yearly"].waitForExistence(timeout: 8)
                || app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "1 year")).firstMatch.exists,
            "Yearly length missing on iPad paywall"
        )
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Monthly")).firstMatch.exists
                || app.debugDescription.lowercased().contains("monthly"),
            "Monthly title missing on iPad paywall"
        )
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Yearly")).firstMatch.exists
                || app.debugDescription.lowercased().contains("yearly"),
            "Yearly title missing on iPad paywall"
        )
        XCTAssertTrue(
            app.buttons["Terms of Use"].exists
                || app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Terms of Use")).firstMatch.exists,
            "Terms of Use missing on iPad paywall"
        )
        attachScreenshot(app, name: "\(shotPrefix)-02-paywall-facts")

        let subscribe = app.descendants(matching: .any)[productButtonID]
        XCTAssertTrue(
            subscribe.waitForExistence(timeout: 20),
            "\(productButtonID) missing — StoreKit catalog empty on iPad?"
        )
        attachScreenshot(app, name: "\(shotPrefix)-03-before-purchase")
        subscribe.tap()

        let successCopy = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Premium activated")
        ).firstMatch
        let deadline = Date().addingTimeInterval(40)
        var completed = false
        while Date() < deadline {
            if !paywall.exists || successCopy.exists {
                completed = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        attachScreenshot(app, name: "\(shotPrefix)-04-after-purchase")
        XCTAssertTrue(completed, "Purchase did not complete on iPad simulator (\(productButtonID))")
        XCTAssertFalse(paywall.exists, "Paywall should dismiss after successful iPad purchase")

        if !settingsRoot.exists {
            app.descendants(matching: .any)["tab.settings"].tap()
        }
        XCTAssertTrue(settingsRoot.waitForExistence(timeout: 8), "Settings should return after purchase")
        attachScreenshot(app, name: "\(shotPrefix)-05-settings-after")
    }

    private func scrollToOpenPaywall(_ app: XCUIApplication) -> XCUIElement {
        let button = app.descendants(matching: .any)["settings.open_paywall"]
        for _ in 0..<8 {
            if button.exists, button.isHittable { return button }
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Upgrade to Premium missing")
        return button
    }
}
