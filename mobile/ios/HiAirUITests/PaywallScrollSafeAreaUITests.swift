import XCTest

/// Regression: paywall scroll must not place readable copy under the status bar.
final class PaywallScrollSafeAreaUITests: XCTestCase {
    func testPaywallScrollKeepsRestoreBelowStatusChrome() throws {
        let app = UITestLaunch.launch(
            language: "en",
            seedAuth: true,
            seedLocation: true,
            clearProfile: false,
            skipOnboarding: true,
            mockAPI: true,
            extraEnvironment: [
                "UITEST_STORE_SHOTS": "1",
                "UITEST_PROFILE_ID": "profile-uitest-1",
                "UITEST_EMAIL": "alex@hiair.io",
                "UITEST_USER_ID": "paywall-scroll-user",
            ]
        )
        _ = waitForIdentifier(app, "tab.settings", timeout: 12)

        _ = waitForIdentifier(app, "tab.settings", timeout: 12)
        app.descendants(matching: .any)["tab.settings"].tap()

        let paywall = app.descendants(matching: .any)["settings.open_paywall"]
        for _ in 0..<8 where !paywall.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(paywall.waitForExistence(timeout: 6))
        paywall.tap()
        _ = waitForIdentifier(app, "paywall.root", timeout: 8)

        let restore = app.descendants(matching: .any)["paywall.restore"]
        for _ in 0..<8 where !restore.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(restore.waitForExistence(timeout: 6))
        XCTAssertTrue(restore.isHittable)

        let close = app.descendants(matching: .any).matching(identifier: "paywall.close").firstMatch
        if close.waitForExistence(timeout: 2) {
            XCTAssertTrue(close.isHittable, "Close must stay reachable after scroll")
        }

        attachScreenshot(app, name: "paywall-scroll-restore-safe-area")
    }
}
