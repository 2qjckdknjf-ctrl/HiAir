import XCTest
@testable import HiAir

final class PlaceGeocodingServiceTests: XCTestCase {
    func testDisplayNamePrefersLocality() {
        let locality = "Barcelona"
        let fallback = "Catalonia"
        let chosen = [locality, nil, fallback].compactMap { $0 }.first { !$0.isEmpty }
        XCTAssertEqual(chosen, "Barcelona")
    }

    func testCoordinateKeyBucketsNearbyPoints() {
        let a = PlaceGeocodingService.coordinateKey(lat: 41.3874, lon: 2.1686)
        let b = PlaceGeocodingService.coordinateKey(lat: 41.38745, lon: 2.16862)
        XCTAssertEqual(a, b)
        let far = PlaceGeocodingService.coordinateKey(lat: 41.2800, lon: 1.9760)
        XCTAssertNotEqual(a, far)
    }

    func testPresentationCacheIsAccountScoped() async {
        let service = PlaceGeocodingService.shared
        await service.clearCacheForTests()
        await service.setPresentationForTests(
            name: "Barcelona",
            lat: 41.3874,
            lon: 2.1686,
            userId: "account-a"
        )
        let forA = await service.presentationPlaceName(for: "account-a")
        let forB = await service.presentationPlaceName(for: "account-b")
        XCTAssertEqual(forA, "Barcelona")
        XCTAssertNil(forB)

        let reused = await service.reusablePresentationName(
            userId: "account-a",
            lat: 41.3875,
            lon: 2.1687
        )
        XCTAssertEqual(reused, "Barcelona")
        let otherAccount = await service.reusablePresentationName(
            userId: "account-b",
            lat: 41.3875,
            lon: 2.1687
        )
        XCTAssertNil(otherAccount)
    }

    func testInvalidateSessionClearsPresentation() async {
        let service = PlaceGeocodingService.shared
        await service.clearCacheForTests()
        await service.setPresentationForTests(
            name: "Barcelona",
            lat: 41.3874,
            lon: 2.1686,
            userId: "account-a"
        )
        await service.invalidateSession()
        let name = await service.presentationPlaceName(for: "account-a")
        XCTAssertNil(name)
    }

    func testRuntimeProbeRecordsDuration() {
        RuntimePerformanceProbe.resetForTests()
        RuntimePerformanceProbe.begin("unit_probe")
        let ms = RuntimePerformanceProbe.end("unit_probe", success: true)
        XCTAssertGreaterThanOrEqual(ms, 0)
        XCTAssertEqual(RuntimePerformanceProbe.lastDurationMs("unit_probe"), ms)
    }
}

final class HealthConsentGateTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        let service = HealthKitService.shared
        service.clearAccountSession()
        UserDefaults.standard.removeObject(forKey: "hiair.health.authorizationCompleted.user-a")
        UserDefaults.standard.removeObject(forKey: "hiair.health.consentPersisted.user-a")
        UserDefaults.standard.removeObject(forKey: "hiair.health.authorizationCompleted.user-b")
        UserDefaults.standard.removeObject(forKey: "hiair.health.consentPersisted.user-b")
        UserDefaults.standard.removeObject(forKey: "hiair.health.authorizationCompleted")
    }

    @MainActor
    func testSystemAuthorizationWithoutConsentIsNotConnected() {
        let service = HealthKitService.shared
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertTrue(service.hasSystemAuthorization(for: "user-a"))
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .systemAuthorized)
        XCTAssertNotEqual(service.connectionState, .connected)
    }

    @MainActor
    func testDurableConsentMarksConnected() {
        let service = HealthKitService.shared
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertTrue(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .connected)
    }

    @MainActor
    func testSyncBlockedWithoutDurableConsent() async {
        let service = HealthKitService.shared
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        // Without durable consent, sync must not flip to connected via artifacts.
        XCTAssertNotEqual(service.connectionState, .connected)
        await service.syncHealthIntelligence(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertNil(service.lastSyncAt)
    }

    @MainActor
    func testAccountIsolationAfterLogout() {
        let service = HealthKitService.shared
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)

        service.clearAccountSession()
        XCTAssertEqual(service.connectionState, .notConnected)
        XCTAssertTrue(service.boundUserId.isEmpty)

        service.bindAccount(userId: "user-b")
        XCTAssertFalse(service.hasDurableConsent(for: "user-b"))
        XCTAssertEqual(service.connectionState, .notConnected)

        // Account A markers remain durable for restore, but B does not inherit Connected.
        XCTAssertTrue(service.hasDurableConsent(for: "user-a"))
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)
    }

    @MainActor
    func testRefreshDoesNotPromoteSystemAuthToConnected() {
        let service = HealthKitService.shared
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        service.bindAccount(userId: "user-a")
        let refreshed = service.refreshAuthorizationState()
        XCTAssertEqual(refreshed, .systemAuthorized)
        XCTAssertNotEqual(refreshed, .connected)
    }
}

final class SessionLogoutIsolationTests: XCTestCase {
    @MainActor
    func testLogoutClearsCityHealthAndPremiumPresentation() async {
        let session = AppSession()
        session.userId = "user-a"
        session.accessToken = "tok"
        session.displayPlaceName = "Barcelona"
        session.isPremium = true
        session.premiumActivationPending = true
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.user-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        HealthKitService.shared.bindAccount(userId: "user-a")
        await PlaceGeocodingService.shared.setPresentationForTests(
            name: "Barcelona",
            lat: 41.3874,
            lon: 2.1686,
            userId: "user-a"
        )

        session.logout()

        XCTAssertTrue(session.userId.isEmpty)
        XCTAssertNil(session.displayPlaceName)
        XCTAssertFalse(session.isPremium)
        XCTAssertFalse(session.premiumActivationPending)
        XCTAssertEqual(HealthKitService.shared.connectionState, .notConnected)

        // Next account must not see A's city from presentation cache.
        let leaked = await PlaceGeocodingService.shared.presentationPlaceName(for: "user-b")
        XCTAssertNil(leaked)
    }

    @MainActor
    func testPremiumRollbackClearsOptimisticUnlock() {
        let session = AppSession()
        let optimistic = UserEntitlementResponse(
            userId: "u1",
            plan: "monthly",
            isPremium: true,
            maxProfiles: 5,
            extendedForecastEnabled: true,
            customAlertsEnabled: true,
            exportReportsEnabled: true,
            advancedInsightsEnabled: true
        )
        session.beginPremiumActivation(optimistic: optimistic)
        XCTAssertTrue(session.isPremium)
        XCTAssertTrue(session.premiumActivationPending)
        session.rollbackPremiumActivation()
        XCTAssertFalse(session.isPremium)
        XCTAssertFalse(session.premiumActivationPending)
    }

    @MainActor
    func testPremiumConfirmClearsPending() {
        let session = AppSession()
        let entitlement = UserEntitlementResponse(
            userId: "u1",
            plan: "monthly",
            isPremium: true,
            maxProfiles: 5,
            extendedForecastEnabled: true,
            customAlertsEnabled: true,
            exportReportsEnabled: true,
            advancedInsightsEnabled: true
        )
        session.beginPremiumActivation(optimistic: entitlement)
        session.confirmPremiumActivation(entitlement)
        XCTAssertTrue(session.isPremium)
        XCTAssertFalse(session.premiumActivationPending)
    }

    @MainActor
    func testTerminalRejectionHelper() {
        XCTAssertTrue(
            SubscriptionService.isTerminalSubscriptionRejection(.server(statusCode: 400))
        )
        XCTAssertTrue(
            SubscriptionService.isTerminalSubscriptionRejection(.server(statusCode: 403))
        )
        XCTAssertFalse(
            SubscriptionService.isTerminalSubscriptionRejection(.server(statusCode: 408))
        )
        XCTAssertFalse(
            SubscriptionService.isTerminalSubscriptionRejection(.server(statusCode: 429))
        )
        XCTAssertFalse(
            SubscriptionService.isTerminalSubscriptionRejection(.server(statusCode: 503))
        )
        XCTAssertFalse(
            SubscriptionService.isTerminalSubscriptionRejection(.invalidResponse)
        )
    }
}

final class PremiumOptimisticUnlockTests: XCTestCase {
    @MainActor
    func testApplyEntitlementSetsPremiumImmediately() {
        let session = AppSession()
        let entitlement = UserEntitlementResponse(
            userId: "u1",
            plan: "monthly",
            isPremium: true,
            maxProfiles: 5,
            extendedForecastEnabled: true,
            customAlertsEnabled: true,
            exportReportsEnabled: true,
            advancedInsightsEnabled: true
        )
        session.applyEntitlement(entitlement)
        XCTAssertTrue(session.isPremium)
        session.applyEntitlement(nil)
        XCTAssertFalse(session.isPremium)
    }
}
