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
        service.resetTestHooks()
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        // Without durable consent, sync must not flip to connected via artifacts.
        XCTAssertNotEqual(service.connectionState, .connected)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.testUploadAttemptCount, 0)
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
    func testEntitlementNotificationIgnoresOtherAccount() {
        let session = AppSession()
        session.userId = "user-b"
        session.isPremium = false
        let foreign = UserEntitlementResponse(
            userId: "user-a",
            plan: "monthly",
            isPremium: true,
            maxProfiles: 5,
            extendedForecastEnabled: true,
            customAlertsEnabled: true,
            exportReportsEnabled: true,
            advancedInsightsEnabled: true
        )
        NotificationCenter.default.post(
            name: .subscriptionEntitlementDidUpdate,
            object: foreign,
            userInfo: ["activationPending": true]
        )
        // Allow MainActor observer Task to run.
        let exp = expectation(description: "entitlement_ignored")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertFalse(session.isPremium)
            XCTAssertFalse(session.premiumActivationPending)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
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

final class HealthSyncCoordinatorRaceTests: XCTestCase {
    @MainActor
    private func seedConnected(_ userId: String) -> HealthKitService {
        let service = HealthKitService.shared
        service.resetTestHooks()
        service.clearAccountSession()
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.\(userId)")
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.\(userId)")
        service.bindAccount(userId: userId)
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertTrue(service.hasDurableConsent(for: userId))
        return service
    }

    @MainActor
    func testRevokeClearsConsentBeforeRemoteAwait() async {
        let service = seedConnected("user-a")
        var sawClearedBeforeAwait = false
        service.testRemoteRevokeHandler = {
            XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
            XCTAssertEqual(service.connectionState, .revoking)
            sawClearedBeforeAwait = true
        }
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        XCTAssertTrue(sawClearedBeforeAwait)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .notConnected)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
    }

    @MainActor
    func testDeleteClearsConsentBeforeRemoteAwait() async {
        let service = seedConnected("user-a")
        var sawClearedBeforeAwait = false
        service.testRemoteDeleteHandler = {
            XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
            XCTAssertEqual(service.connectionState, .revoking)
            sawClearedBeforeAwait = true
        }
        await service.deleteHealthData(userId: "user-a", accessToken: "token")
        XCTAssertTrue(sawClearedBeforeAwait)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .notConnected)
    }

    @MainActor
    func testDashboardStyleSyncRevokePreventsUpload() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return ([], nil)
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 30_000_000)
        service.testRemoteRevokeHandler = {}
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertNotEqual(service.connectionState, .connected)
    }

    @MainActor
    func testDeleteDuringSyncPreventsUpload() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return ([], nil)
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 30_000_000)
        service.testRemoteDeleteHandler = {}
        await service.deleteHealthData(userId: "user-a", accessToken: "token")
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
    }

    @MainActor
    func testLogoutDuringSyncPreventsUpload() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return ([], nil)
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 30_000_000)
        service.clearAccountSession()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertEqual(service.connectionState, .notConnected)
    }

    @MainActor
    func testAccountSwitchDuringSyncDoesNotUploadForOldAccount() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            try? await Task.sleep(nanoseconds: 150_000_000)
            return ([], nil)
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 30_000_000)
        service.clearAccountSession()
        service.bindAccount(userId: "user-b")
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertEqual(service.connectionState, .notConnected)
        XCTAssertFalse(service.hasDurableConsent(for: "user-b"))
    }

    @MainActor
    func testCancelAfterCollectBeforeUpload() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testBeforeUploadHook = {
            service.cancelPendingSync()
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
    }

    @MainActor
    func testDuplicateStartReplacesGeneration() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            try? await Task.sleep(nanoseconds: 200_000_000)
            return ([], nil)
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        let firstGeneration = service.syncGenerationForTests
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        let secondGeneration = service.syncGenerationForTests
        XCTAssertGreaterThan(secondGeneration, firstGeneration)
        service.cancelPendingSync()
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    @MainActor
    func testSlowRemoteRevokeStillBlocksSync() async {
        let service = seedConnected("user-a")
        service.testRemoteRevokeHandler = {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let revokeTask = Task { await service.revokeConsent(userId: "user-a", accessToken: "token") }
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        await revokeTask.value
        XCTAssertEqual(service.connectionState, .notConnected)
    }

    @MainActor
    func testRemoteRevokeFailureKeepsSyncBlocked() async {
        let service = seedConnected("user-a")
        service.testRemoteRevokeHandler = {
            throw NSError(domain: "test", code: 500, userInfo: [NSLocalizedDescriptionKey: "remote"])
        }
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .remoteRevokePending)
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
    }

    @MainActor
    func testConsensedSyncCompletesOnceViaCoordinator() async {
        let service = seedConnected("user-a")
        service.testCollectHandler = {
            (
                [
                    HealthMetricSnapshot(
                        metricType: "steps",
                        unit: "count",
                        valueAvg: nil,
                        valueMin: nil,
                        valueMax: nil,
                        valueLatest: nil,
                        valueTotal: 100,
                        sampleCount: 1,
                        qualityState: "ok",
                        hrvMethod: nil
                    ),
                ],
                nil
            )
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertEqual(service.testUploadAttemptCount, 2) // health_sync + daily_summary test path
        XCTAssertNotNil(service.lastSyncAt)
    }

    @MainActor
    func testReconnectRequiredAfterRevoke() async {
        let service = seedConnected("user-a")
        service.testRemoteRevokeHandler = {}
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        // Restore only after explicit durable consent again.
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.user-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)
    }
}

