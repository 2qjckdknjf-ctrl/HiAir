import XCTest

/// Verifies root tab scroll clearance: last control must sit above floating tab bar.
final class MainTabScrollHittabilityUITests: XCTestCase {
    private struct TabProbe {
        let tabID: String
        let bottomID: String
    }

    private let probes: [TabProbe] = [
        TabProbe(tabID: "tab.dashboard", bottomID: "dashboard.log_symptoms"),
        TabProbe(tabID: "tab.planner", bottomID: "planner.refresh"),
        TabProbe(tabID: "tab.insights", bottomID: "insights.refresh"),
        TabProbe(tabID: "tab.symptoms", bottomID: "symptoms.add_custom"),
        TabProbe(tabID: "tab.settings", bottomID: "settings.logout"),
    ]

    func testRootTabsLastControlClearsFloatingTabBar() throws {
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
                "UITEST_USER_ID": "uitest-scroll-user",
            ]
        )

        for probe in probes {
            try assertScrollClearance(app: app, tabID: probe.tabID, bottomID: probe.bottomID)
        }
    }

    private func assertScrollClearance(app: XCUIApplication, tabID: String, bottomID: String) throws {
        let tabButton = app.descendants(matching: .any)[tabID]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 10), "Missing tab \(tabID)")
        tabButton.tap()

        let target = app.descendants(matching: .any)[bottomID]
        for _ in 0..<12 where !target.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        XCTAssertTrue(target.waitForExistence(timeout: 8), "Missing bottom control \(bottomID) on \(tabID)")
        XCTAssertTrue(target.isHittable, "Bottom control \(bottomID) not hittable on \(tabID)")

        let tabBar = app.descendants(matching: .any)["tab.bar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 4), "Missing tab.bar chrome")

        let targetBottom = target.frame.maxY
        let barTop = tabBar.frame.minY
        XCTAssertLessThan(
            targetBottom,
            barTop - 4,
            "Control \(bottomID) overlaps tab bar on \(tabID): bottom=\(targetBottom) barTop=\(barTop)"
        )
    }
}
