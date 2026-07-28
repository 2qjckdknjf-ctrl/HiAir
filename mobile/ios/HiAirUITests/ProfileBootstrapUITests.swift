import XCTest

final class ProfileBootstrapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCreateProfileCTASucceedsWithMockAPI() throws {
        let app = UITestLaunch.launch()
        attachScreenshot(app, name: "01-dashboard-before-create")
        attachA11yDump(app, name: "01-dashboard-before-create")

        let cta = waitForIdentifier(app, "dashboard.create_profile")
        cta.tap()

        let loading = app.descendants(matching: .any)["profile_ensure.loading"]
        // Loading may be brief; either loading appears or CTA disappears after success.
        _ = loading.waitForExistence(timeout: 2)

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if !cta.exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        attachScreenshot(app, name: "02-dashboard-after-create")
        attachA11yDump(app, name: "02-dashboard-after-create")
        XCTAssertFalse(cta.exists, "Create profile CTA should disappear after successful bootstrap")
        XCTAssertFalse(app.descendants(matching: .any)["profile_ensure.error"].exists)
        // Profile empty-state title must be gone (bootstrap postcondition).
        XCTAssertFalse(app.staticTexts["Профиль не настроен"].exists)
        // Mocked current-risk should prevent the dashboard API-error empty state.
        XCTAssertFalse(app.staticTexts["Не удалось загрузить данные."].waitForExistence(timeout: 3))
    }

    func testCreateProfileNeedsLocationShowsError() throws {
        let app = UITestLaunch.launch(seedLocation: false, extraEnvironment: [
            "UITEST_SEED_LOCATION": "0",
        ])
        // Explicitly clear coords by not seeding; also force zeros via env absence.
        attachScreenshot(app, name: "03-needs-location-before")

        let cta = waitForIdentifier(app, "dashboard.create_profile", timeout: 10)
        cta.tap()

        let error = waitForIdentifier(app, "profile_ensure.error", timeout: 8)
        attachScreenshot(app, name: "03-needs-location-after")
        attachA11yDump(app, name: "03-needs-location-after")
        XCTAssertTrue(error.exists)
        XCTAssertTrue(cta.exists, "CTA remains for retry when location missing")
    }

    func testCreateProfileShowsUnavailableOn503() throws {
        let app = UITestLaunch.launch(extraEnvironment: [
            "UITEST_PROFILES_STATUS": "503",
        ])
        let cta = waitForIdentifier(app, "dashboard.create_profile")
        cta.tap()
        let error = waitForIdentifier(app, "profile_ensure.error", timeout: 8)
        attachScreenshot(app, name: "05-profile-503")
        XCTAssertTrue(error.exists)
        XCTAssertTrue(cta.exists)
    }

    func testCreateProfileUnauthorizedReturnsToAuth() throws {
        let app = UITestLaunch.launch(extraEnvironment: [
            "UITEST_PROFILES_STATUS": "401",
        ])
        let cta = waitForIdentifier(app, "dashboard.create_profile")
        cta.tap()
        let auth = waitForIdentifier(app, "auth.root", timeout: 10)
        attachScreenshot(app, name: "06-profile-401-auth")
        XCTAssertTrue(auth.exists)
    }
}

final class TabNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabsReachableAfterSeededSession() throws {
        let app = UITestLaunch.launch(clearProfile: false, extraEnvironment: [
            "UITEST_PROFILE_ID": "profile-seed",
            "UITEST_CLEAR_PROFILE": "0",
        ])
        attachScreenshot(app, name: "10-tabs-dashboard")

        app.tabBars.buttons.element(boundBy: 1).tap()
        attachScreenshot(app, name: "11-tabs-planner")
        app.tabBars.buttons.element(boundBy: 2).tap()
        attachScreenshot(app, name: "12-tabs-insights")
        app.tabBars.buttons.element(boundBy: 3).tap()
        attachScreenshot(app, name: "13-tabs-symptoms")
        app.tabBars.buttons.element(boundBy: 4).tap()
        attachScreenshot(app, name: "14-tabs-settings")

        let logout = app.descendants(matching: .any)["settings.logout"]
        XCTAssertTrue(logout.waitForExistence(timeout: 6), "Settings logout control should be reachable")
        attachA11yDump(app, name: "14-tabs-settings")
    }

    func testEnglishLanguageLaunch() throws {
        let app = UITestLaunch.launch(language: "en")
        attachScreenshot(app, name: "20-en-dashboard")
        let cta = waitForIdentifier(app, "dashboard.create_profile")
        XCTAssertTrue(cta.label.lowercased().contains("create") || cta.label.contains("Create"))
    }

    func testPaywallOpenAndClose() throws {
        let app = UITestLaunch.launch(clearProfile: false, extraEnvironment: [
            "UITEST_PROFILE_ID": "profile-seed",
            "UITEST_CLEAR_PROFILE": "0",
        ])
        app.tabBars.buttons.element(boundBy: 4).tap()
        let openPaywall = waitForIdentifier(app, "settings.open_paywall", timeout: 8)
        openPaywall.tap()
        let closeQuery = app.descendants(matching: .any).matching(identifier: "paywall.close")
        let close = closeQuery.element(boundBy: 0)
        XCTAssertTrue(close.waitForExistence(timeout: 8), "Missing paywall.close")
        attachScreenshot(app, name: "30-paywall-open")
        close.tap()
        attachScreenshot(app, name: "31-paywall-closed")
        XCTAssertTrue(openPaywall.waitForExistence(timeout: 5))
    }

    func testLogoutReturnsToAuth() throws {
        let app = UITestLaunch.launch(clearProfile: false, extraEnvironment: [
            "UITEST_PROFILE_ID": "profile-seed",
            "UITEST_CLEAR_PROFILE": "0",
        ])
        app.tabBars.buttons.element(boundBy: 4).tap()
        let logout = waitForIdentifier(app, "settings.logout", timeout: 8)
        logout.tap()
        let auth = waitForIdentifier(app, "auth.root", timeout: 8)
        attachScreenshot(app, name: "40-logout-auth")
        XCTAssertTrue(auth.exists)
        XCTAssertTrue(app.descendants(matching: .any)["auth.log_in"].waitForExistence(timeout: 4))
    }
}

final class AuthScreenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAuthScreenControlsPresent() throws {
        let app = UITestLaunch.launch(seedAuth: false, clearProfile: false, skipOnboarding: false)
        attachScreenshot(app, name: "50-auth-root")
        attachA11yDump(app, name: "50-auth-root")
        _ = waitForIdentifier(app, "auth.root")
        _ = waitForIdentifier(app, "auth.email")
        _ = waitForIdentifier(app, "auth.password")
        _ = waitForIdentifier(app, "auth.log_in")
        _ = waitForIdentifier(app, "auth.sign_up")
    }
}
