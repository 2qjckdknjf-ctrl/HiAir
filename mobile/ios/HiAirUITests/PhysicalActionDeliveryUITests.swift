import XCTest

/// Opt-in on-device checks using the installed account/session and live API.
/// No seeded auth, mocked API, account deletion, health-permission changes or purchases.
final class PhysicalActionDeliveryUITests: XCTestCase {
    func testExistingSessionPlannerAndCalendarCancel() throws {
        guard ProcessInfo.processInfo.environment["HIAIR_RUN_PHYSICAL_QA"] == "1" else {
            throw XCTSkip("Run explicitly against a physical signed candidate after production deploy")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.hiair.app")
        app.launch()
        let home = app.descendants(matching: .any)["tab.dashboard"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 30), "Existing session did not restore")
        for id in ["tab.planner", "tab.insights", "tab.symptoms", "tab.settings", "tab.planner"] {
            let tab = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 10))
            tab.tap()
        }
        let time = app.descendants(matching: .any)["planner.action.time"].firstMatch
        for _ in 0..<10 {
            if time.exists && time.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(time.waitForExistence(timeout: 30), "Missing live Action configuration")
        let calendar = app.buttons["planner.action.calendar"]
        for _ in 0..<10 {
            if calendar.exists && calendar.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(calendar.waitForExistence(timeout: 30), "No trusted Best Time / calendar action")
        calendar.tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Отменить", "Отмена", "Cancelar", "Annulla", "Annuler"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Native calendar editor not presented")
        cancel.tap()
        XCTAssertTrue(app.descendants(matching: .any)["tab.planner"].firstMatch.waitForExistence(timeout: 10))
    }
}


/// Real primary Insights response, not merely navigation or a spinner dismissal.
final class PhysicalRuntimePerformanceUITests: XCTestCase {
    func testPrimaryInsightsLoadsWithinEightSeconds() throws {
        guard ProcessInfo.processInfo.environment["HIAIR_RUN_PHYSICAL_QA"] == "1" else {
            throw XCTSkip("Opt-in physical Release/live-API check")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier:"com.hiair.app")
        app.launch()
        let tab = app.descendants(matching:.any)["tab.insights"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout:30),"Existing session must restore")
        let started = Date()
        tab.tap()
        let primary = app.descendants(matching:.any)["insights.primary.ready"].firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout:8),"Primary live Insights did not load within the budget")
        let seconds = Date().timeIntervalSince(started)
        XCTAssertLessThan(seconds,10,"Includes native tab-tap overhead; server/client timings are in diagnostics")
        print("Primary physical Insights observed in \(String(format:"%.2f",seconds)) seconds")
    }
}
