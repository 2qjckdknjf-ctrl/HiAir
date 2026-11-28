import XCTest
@testable import HiAir

final class ProductAnalyticsConsentTests: XCTestCase {
    private var defaults: UserDefaults!
    private var previousAuth: APIClient.AuthState?

    private func signIn(_ userId: String) {
        APIClient.setAuthState(.init(userId: userId, accessToken: "test-token", refreshToken: "test-refresh"))
    }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "hiair.product.analytics.tests.\(UUID().uuidString)")
        ProductAnalytics.defaults = defaults
        previousAuth = APIClient.getAuthState()
        signIn("user-a")
        ProductAnalytics.setAnalyticsConsent(false)
        ProductAnalytics.testEventSink = nil
    }

    override func tearDown() {
        ProductAnalytics.testEventSink = nil
        ProductAnalytics.defaults = .standard
        APIClient.setAuthState(previousAuth)
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
        defaults.set("2026-11-01", forKey: "hiair.product_analytics.first_open_day.account.user-a")
        defaults.set("2026-11-01", forKey: "hiair.product_analytics.last_open_day.account.user-a")
        ProductAnalytics.recordAppOpen(surface: "dashboard")
        XCTAssertTrue(names.contains(ProductAnalytics.Event.repeatUse))
    }

    func testLegacyDeviceConsentAndCountersAreNotInherited() {
        defaults.set(true, forKey: "hiair.product_analytics.consent")
        defaults.set(true, forKey: "hiair.product_analytics.first_useful_sent")
        var names: [String] = []
        ProductAnalytics.testEventSink = { name, _ in names.append(name) }
        signIn("user-b")
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertTrue(names.isEmpty)
        ProductAnalytics.setAnalyticsConsent(true)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertEqual(names, [ProductAnalytics.Event.firstUsefulRecommendation])
    }

    func testConsentAndFirstUsefulCountersStayWithTheirAccount() {
        var names: [String] = []
        ProductAnalytics.testEventSink = { name, _ in names.append(name) }
        ProductAnalytics.setAnalyticsConsent(true)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        APIClient.setAuthState(nil)
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        signIn("user-b")
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertEqual(names.count, 1)
        ProductAnalytics.setAnalyticsConsent(true)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertEqual(names.count, 2)
        signIn("user-a")
        XCTAssertTrue(ProductAnalytics.analyticsConsentGranted)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard")
        XCTAssertEqual(names.count, 2)
    }

    func testDelayedRecommendationCannotUseAnotherAccountsConsentOrCounter() {
        signIn("user-b")
        ProductAnalytics.setAnalyticsConsent(true)
        var names: [String] = []
        ProductAnalytics.testEventSink = { name, _ in names.append(name) }
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard", userId: "user-a")
        XCTAssertTrue(names.isEmpty)
        ProductAnalytics.recordUsefulRecommendation(surface: "dashboard", userId: "user-b")
        XCTAssertEqual(names, [ProductAnalytics.Event.firstUsefulRecommendation])
    }

    func testAnonymousConsentCannotAuthorizeTheNextLogin() {
        APIClient.setAuthState(nil)
        ProductAnalytics.setAnalyticsConsent(true)
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
        signIn("user-b")
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
    }

    @MainActor
    func testSettingsRefreshesPersistedConsentWithoutGrantingItToTheNextAccount() {
        let model = SettingsViewModel()
        ProductAnalytics.setAnalyticsConsent(true)
        model.refreshProductAnalyticsConsent(userId: "user-a")
        let oldBinding = model.productAnalyticsBinding(userId: "user-a")
        XCTAssertTrue(model.productAnalyticsEnabled)
        signIn("user-b")
        model.refreshProductAnalyticsConsent(userId: "user-b")
        XCTAssertFalse(model.productAnalyticsEnabled)
        oldBinding.wrappedValue = true
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
        model.setProductAnalyticsEnabled(true, userId: "user-b")
        XCTAssertTrue(model.productAnalyticsEnabled)
        oldBinding.wrappedValue = false
        XCTAssertTrue(ProductAnalytics.analyticsConsentGranted)
        XCTAssertTrue(model.productAnalyticsEnabled)
        APIClient.setAuthState(nil)
        model.refreshProductAnalyticsConsent(userId: "")
        XCTAssertFalse(model.productAnalyticsEnabled)
    }

    func testPartialRestoredAccountCannotGrantConsentWithoutAnAccessToken() {
        for token in ["", " \n "] {
            APIClient.setAuthState(.init(userId: "user-b", accessToken: token, refreshToken: ""))
            XCTAssertFalse(ProductAnalytics.setAnalyticsConsent(true))
        }
        signIn("user-b")
        XCTAssertFalse(ProductAnalytics.analyticsConsentGranted)
    }
}
