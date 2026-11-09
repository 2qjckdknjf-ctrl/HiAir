import XCTest

/// Runs against the already installed TestFlight app via UseDestinationArtifacts.
/// No fixtures, session seeding, StoreKit configuration, or automatic Apple confirmation.
final class PhysicalInstalledStoreUITests: XCTestCase {
    private func app() throws -> XCUIApplication {
        guard ProcessInfo.processInfo.environment["HIAIR_RUN_PHYSICAL_QA"] == "1" else {
            throw XCTSkip("Explicit physical-device invocation required")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.hiair.app")
        app.launch()
        XCTAssertTrue(app.buttons["tab.dashboard"].waitForExistence(timeout: 30))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testDashboardObservedStates() throws {
        let app = try app()
        app.buttons["tab.dashboard"].tap()
        let started = Date()
        capture(app, "dashboard-initial")
        // Observation windows are not success criteria; inspect real content in attachments.
        for seconds in [5.0, 15.0, 30.0] {
            let until = Date().addingTimeInterval(max(0, seconds - Date().timeIntervalSince(started)))
            RunLoop.current.run(until: until)
            capture(app, "dashboard-at-\(seconds)s")
        }
    }

    func testDashboardLoadsRealRiskAfterRecovery() throws {
        let started = Date()
        let app = try app()
        app.buttons["tab.dashboard"].tap()
        let retry = app.buttons["dashboard.create_profile"]
        if retry.exists && retry.isHittable { retry.tap() }
        let risk = app.descendants(matching: .any).matching(NSPredicate(
            format: "label MATCHES[c] %@", "(Низкий|Умеренный|Высокий|Очень высокий|Low|Moderate|High|Very high) [0-9]+"
        )).firstMatch
        XCTAssertTrue(risk.waitForExistence(timeout: 45), "No real risk value after database recovery")
        let elapsed = Date().timeIntervalSince(started)
        capture(app, "database-recovery-risk")
        let measurement = XCTAttachment(string: "launch_to_risk_seconds=\(elapsed);risk=\(risk.label)")
        measurement.name = "useful-data-latency"
        measurement.lifetime = .keepAlways
        add(measurement)
        XCTAssertFalse(app.descendants(matching: .any)["profile_ensure.error"].exists)
        XCTAssertFalse(app.buttons["dashboard.create_profile"].exists)
    }

    func testHealthConsentAfterDatabaseRecovery() throws {
        let app = try app()
        app.buttons["tab.settings"].tap()
        let connect = app.buttons["settings.wearables.connect"]
        for _ in 0..<16 {
            if connect.exists && connect.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(connect.exists && connect.isHittable)
        capture(app, "health-before-recovery")
        connect.tap()
        let confirm = app.buttons["wearable.consent.continue"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        // Existing scopes only. If Apple asks for permission, the owner confirms on device.
        let status = app.descendants(matching: .any)["settings.wearables.status"]
        let connected = NSPredicate(format: "exists == true AND (label CONTAINS[c] %@ OR label CONTAINS[c] %@)", ": подключено", ": connected")
        let expectation = XCTNSPredicateExpectation(predicate: connected, object: status)
        let result = XCTWaiter.wait(for: [expectation], timeout: 90)
        capture(app, "health-after-recovery")
        XCTAssertEqual(result, .completed, "No connected state; inspect Apple prompt and server consent before claiming success")
        XCTAssertFalse(confirm.exists, "Consent dialog must close after server success")
    }

    func testMonthlyPurchaseOnInstalledApp() throws { try openPurchase("monthly") }
    func testYearlyPurchaseOnInstalledApp() throws { try openPurchase("yearly") }

    func testObserveAppleSubscriptionsWithoutPurchase() throws {
        let app = try app()
        app.buttons["tab.settings"].tap()
        let open = app.buttons["settings.open_paywall"]
        for _ in 0..<12 {
            if open.exists && open.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(open.exists && open.isHittable)
        open.tap()
        let manage = app.buttons["Управлять подпиской"]
        for _ in 0..<12 {
            if manage.exists && manage.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(manage.exists && manage.isHittable)
        manage.tap()
        // Observe only: do not renew, cancel, change plans, or confirm payments.
        RunLoop.current.run(until: Date().addingTimeInterval(12))
        capture(app, "apple-subscriptions")
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "apple-subscriptions-full-screen"
        screen.lifetime = .keepAlways
        add(screen)
    }

    func testObserveRestoreWithoutRelaunch() throws {
        guard ProcessInfo.processInfo.environment["HIAIR_RUN_PHYSICAL_QA"] == "1" else {
            throw XCTSkip("Explicit physical-device invocation required")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.hiair.app")
        app.activate()
        let settings = app.buttons["tab.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        let restore = app.buttons["settings.restore_purchases"]
        for _ in 0..<12 {
            if restore.exists && restore.isHittable { break }
            app.swipeUp()
        }
        capture(app, "restore-before")
        XCTAssertTrue(restore.exists && restore.isHittable && restore.isEnabled)
        restore.tap()
        let complete = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: complete, object: restore)
        _ = XCTWaiter.wait(for: [expectation], timeout: 40)
        capture(app, "restore-after")
    }

    private func openPurchase(_ period: String) throws {
        let app = try app()
        app.buttons["tab.settings"].tap()
        let open = app.buttons["settings.open_paywall"]
        for _ in 0..<12 {
            if open.exists && open.isHittable { break }
            app.swipeUp()
        }
        capture(app, "settings-before-\(period)")
        XCTAssertTrue(open.exists && open.isHittable, "No purchase CTA: inspect confirmed entitlement before attempting another purchase")
        open.tap()
        let buy = app.buttons["paywall.subscribe_\(period)"]
        XCTAssertTrue(buy.waitForExistence(timeout: 25), "Real store product did not load")
        for _ in 0..<8 {
            if buy.isHittable { break }
            app.swipeUp()
        }
        capture(app, "\(period)-before-tap")
        XCTAssertTrue(buy.isEnabled && buy.isHittable)
        buy.tap()
        capture(app, "\(period)-after-tap")
        // User confirms the Apple sheet. Never tap payment confirmation here.
        let managed = app.buttons["settings.manage_subscription"]
        let confirmed = managed.waitForExistence(timeout: 120)
        capture(app, "\(period)-final")
        XCTAssertTrue(confirmed, "No confirmed Premium management state after purchase; inspect Apple/backend outcome")
        XCTAssertFalse(app.buttons["paywall.close"].exists, "Paywall did not return to source context")
    }
}
