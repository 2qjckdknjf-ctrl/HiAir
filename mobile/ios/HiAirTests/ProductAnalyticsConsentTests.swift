import XCTest
@testable import HiAir

final class ProductAnalyticsConsentTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "hiair.product.analytics.tests.\(UUID().uuidString)")
        ProductAnalytics.defaults = defaults
        ProductAnalytics.setAnalyticsConsent(false)
        ProductAnalytics.testEventSink = nil
    }

    override func tearDown() {
        ProductAnalytics.testEventSink = nil
        ProductAnalytics.defaults = .standard
        super.tearDown()
    }

    func testRoadmapEventsRequireConsent() {
        var names: [String] = []
        ProductAnalytics.testEventSink = { name, _ in names.append(name) }
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertTrue(names.isEmpty)

        ProductAnalytics.setAnalyticsConsent(true)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertEqual(names, [ProductAnalytics.Event.firstUsefulRecommendation])
    }

    func testRepeatUseEmitsOncePerDayAfterFirstOpen() {
        var names: [String] = []
        ProductAnalytics.testEventSink = { name, _ in names.append(name) }
        ProductAnalytics.setAnalyticsConsent(true)
        ProductAnalytics.recordAppOpen(surface: "dashboard")
        XCTAssertTrue(names.isEmpty, "first open seeds state only")

        // Force previous day so the next open counts as repeat.
        defaults.set("2026-11-01", forKey: "hiair.product_analytics.first_open_day")
        defaults.set("2026-11-01", forKey: "hiair.product_analytics.last_open_day")
        ProductAnalytics.recordAppOpen(surface: "dashboard")
        XCTAssertTrue(names.contains(ProductAnalytics.Event.repeatUse))
    }
}
