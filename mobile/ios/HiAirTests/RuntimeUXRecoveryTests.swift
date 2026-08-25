import XCTest
@testable import HiAir

final class PlaceGeocodingServiceTests: XCTestCase {
    private static let serialLock = NSLock()

    override func invokeTest() {
        Self.serialLock.lock()
        defer { Self.serialLock.unlock() }
        super.invokeTest()
    }

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
        // Isolated actor — never share with AppSession logout Tasks that invalidate `.shared`.
        let service = PlaceGeocodingService()
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
        let service = PlaceGeocodingService()
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

/// Serializes all tests that mutate `HealthKitService.shared`.
enum HealthKitServiceTestLock {
    static let lock = NSLock()
}

final class HealthConsentGateTests: XCTestCase {
    override func setUp() {
        HealthKitServiceTestLock.lock.lock()
    }

    override func tearDown() {
        HealthKitServiceTestLock.lock.unlock()
    }

    @MainActor
    override func setUp() async throws {
        let service = HealthKitService.shared
        service.prepareForUnitTests()
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
        session.cancelLifecycleForTests()
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
        session.cancelLifecycleForTests()
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
        session.cancelLifecycleForTests()
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
        session.cancelLifecycleForTests()
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
    func testRollbackNotificationRequiresMatchingAccount() {
        XCTAssertFalse(
            AppSession.shouldApplyRollbackNotification(currentUserId: "user-b", notedUserId: "user-a")
        )
        XCTAssertFalse(
            AppSession.shouldApplyRollbackNotification(currentUserId: "user-b", notedUserId: nil)
        )
        XCTAssertFalse(
            AppSession.shouldApplyRollbackNotification(currentUserId: "user-b", notedUserId: "")
        )
        XCTAssertFalse(
            AppSession.shouldApplyRollbackNotification(currentUserId: "", notedUserId: "user-b")
        )
        XCTAssertTrue(
            AppSession.shouldApplyRollbackNotification(currentUserId: "user-b", notedUserId: "user-b")
        )

        let session = AppSession()
        session.cancelLifecycleForTests()
        session.userId = "user-b"
        session.isPremium = true
        session.premiumActivationPending = true
        if AppSession.shouldApplyRollbackNotification(currentUserId: session.userId, notedUserId: "user-a") {
            session.rollbackPremiumActivation()
        }
        XCTAssertTrue(session.isPremium)
        XCTAssertTrue(session.premiumActivationPending)
        if AppSession.shouldApplyRollbackNotification(currentUserId: session.userId, notedUserId: "user-b") {
            session.rollbackPremiumActivation()
        }
        XCTAssertFalse(session.isPremium)
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
        session.cancelLifecycleForTests()
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
    /// Shared flags for in-flight collect coordination (cancellation-aware).
    private final class CollectProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var entered = false
        private var release = false

        func markEntered() {
            lock.lock()
            entered = true
            lock.unlock()
        }

        var hasEntered: Bool {
            lock.lock()
            defer { lock.unlock() }
            return entered
        }

        func allowFinish() {
            lock.lock()
            release = true
            lock.unlock()
        }

        func waitUntilReleasedOrCancelled() async {
            while true {
                if Task.isCancelled { return }
                if isReleased { return }
                await Task.yield()
            }
        }

        private var isReleased: Bool {
            lock.lock()
            defer { lock.unlock() }
            return release
        }
    }

    /// Ephemeral defaults suite — never mutates `HealthKitService.shared` /
    /// `UserDefaults.standard` owned by the XCTest host AppSession.
    private var isolatedSuiteName: String?
    private var isolatedDefaults: UserDefaults?

    override func setUp() {
        HealthKitServiceTestLock.lock.lock()
    }

    override func tearDown() {
        if let suite = isolatedSuiteName {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        isolatedSuiteName = nil
        isolatedDefaults = nil
        HealthKitServiceTestLock.lock.unlock()
    }

    @MainActor
    override func setUp() async throws {
        let suite = "hiair.tests.health.\(UUID().uuidString)"
        isolatedSuiteName = suite
        isolatedDefaults = UserDefaults(suiteName: suite)
        XCTAssertNotNil(isolatedDefaults)
    }

    @MainActor
    private func makeIsolatedService() -> HealthKitService {
        let defaults = isolatedDefaults ?? UserDefaults.standard
        let service = HealthKitService(defaults: defaults)
        service.prepareForUnitTests()
        return service
    }

    @MainActor
    private func seedConnected(_ userId: String) async -> HealthKitService {
        let service = makeIsolatedService()
        for _ in 0..<200 where service.hasSyncInFlightForTests {
            await Task.yield()
        }
        service.seedDurableConsentMarkersForTests(userId: userId)
        service.bindAccount(userId: userId)
        service.reportConnectionState(.connected)
        XCTAssertEqual(service.connectionState, .connected)
        XCTAssertTrue(service.hasDurableConsent(for: userId))
        return service
    }

    @MainActor
    private func awaitSyncIdle(_ service: HealthKitService, maxYields: Int = 2_000) async {
        for _ in 0..<maxYields {
            if !service.hasSyncInFlightForTests { return }
            await Task.yield()
        }
    }

    @MainActor
    private func awaitCollectEntered(_ probe: CollectProbe, maxAttempts: Int = 400) async -> Bool {
        for _ in 0..<maxAttempts {
            if probe.hasEntered { return true }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        return probe.hasEntered
    }

    @MainActor
    func testRevokeClearsConsentBeforeRemoteAwait() async {
        let service = await seedConnected("user-a")
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
        let service = await seedConnected("user-a")
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
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testRemoteRevokeHandler = {}
        service.testBeforeUploadHook = {
            await service.revokeConsent(userId: "user-a", accessToken: "token")
        }
        await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertGreaterThan(service.testUploadGateReachedCount, 0)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertNotEqual(service.connectionState, .connected)
    }

    @MainActor
    func testDeleteDuringSyncPreventsUpload() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testRemoteDeleteHandler = {}
        service.testBeforeUploadHook = {
            await service.deleteHealthData(userId: "user-a", accessToken: "token")
        }
        await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertGreaterThan(service.testUploadGateReachedCount, 0)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
    }

    @MainActor
    func testLogoutDuringSyncPreventsUpload() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testBeforeUploadHook = {
            service.clearAccountSession()
        }
        await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertGreaterThan(service.testUploadGateReachedCount, 0)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertEqual(service.connectionState, .notConnected)
    }

    @MainActor
    func testAccountSwitchDuringSyncDoesNotUploadForOldAccount() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testBeforeUploadHook = {
            service.clearAccountSession()
            service.bindAccount(userId: "user-b")
        }
        await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertGreaterThan(service.testUploadGateReachedCount, 0)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertEqual(service.connectionState, .notConnected)
        XCTAssertFalse(service.hasDurableConsent(for: "user-b"))
    }

    @MainActor
    func testCancelAfterCollectBeforeUpload() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        service.testBeforeUploadHook = {
            service.cancelPendingSync()
        }
        await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertGreaterThan(service.testUploadGateReachedCount, 0)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasSyncInFlightForTests)
    }

    @MainActor
    func testDuplicateStartReplacesGenerationAndKeepsNewerHandle() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        let firstHold = CollectProbe()
        let secondHold = CollectProbe()
        var phase = 0
        service.testBeforeUploadHook = {
            phase += 1
            if phase == 1 {
                firstHold.markEntered()
                await firstHold.waitUntilReleasedOrCancelled()
            } else {
                secondHold.markEntered()
                await secondHold.waitUntilReleasedOrCancelled()
            }
        }

        let firstRun = Task { @MainActor in
            await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        }
        let enteredFirst = await awaitCollectEntered(firstHold)
        XCTAssertTrue(enteredFirst)
        let firstGeneration = service.syncGenerationForTests
        XCTAssertTrue(service.hasSyncInFlightForTests)

        let secondRun = Task { @MainActor in
            await service.runHealthSyncForTests(userId: "user-a", accessToken: "token", profileId: nil)
        }
        // Wait until replacement actually began (generation bump + second upload gate).
        let enteredSecond = await awaitCollectEntered(secondHold)
        XCTAssertTrue(enteredSecond)
        let secondGeneration = service.syncGenerationForTests
        XCTAssertGreaterThan(secondGeneration, firstGeneration)
        XCTAssertTrue(service.hasSyncInFlightForTests)

        // Superseded first task may finish now; must not wipe the replacement handle.
        firstHold.allowFinish()
        _ = await firstRun.value
        XCTAssertTrue(service.hasSyncInFlightForTests)
        XCTAssertEqual(service.syncGenerationForTests, secondGeneration)

        secondHold.allowFinish()
        _ = await secondRun.value
        await awaitSyncIdle(service)
        XCTAssertFalse(service.hasSyncInFlightForTests)
        // Only the replacement generation completed uploads (health_sync + daily_summary).
        XCTAssertEqual(service.testUploadAttemptCount, 2)
    }

    @MainActor
    func testBeginSyncClearsCancelledStaleHandleBeforeReplacement() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        let hold = CollectProbe()
        service.testBeforeUploadHook = {
            hold.markEntered()
            await hold.waitUntilReleasedOrCancelled()
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        let entered = await awaitCollectEntered(hold)
        XCTAssertTrue(entered)
        XCTAssertTrue(service.hasSyncInFlightForTests)
        service.cancelPendingSync()
        XCTAssertFalse(service.hasSyncInFlightForTests)
        hold.allowFinish()
        await awaitSyncIdle(service)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
    }

    @MainActor
    func testDuplicateStartJoinsExistingGeneration() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        let hold = CollectProbe()
        service.testBeforeUploadHook = {
            hold.markEntered()
            await hold.waitUntilReleasedOrCancelled()
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        let firstGeneration = service.syncGenerationForTests
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.syncGenerationForTests, firstGeneration)
        XCTAssertTrue(service.hasSyncInFlightForTests)
        service.cancelPendingSync()
        hold.allowFinish()
        await awaitSyncIdle(service)
    }

    @MainActor
    func testForceRestartReplacesGeneration() async {
        let service = await seedConnected("user-a")
        service.testCollectHandler = { ([], nil) }
        let hold = CollectProbe()
        service.testBeforeUploadHook = {
            hold.markEntered()
            await hold.waitUntilReleasedOrCancelled()
        }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        let firstGeneration = service.syncGenerationForTests
        service.startBackgroundHealthSync(
            userId: "user-a",
            accessToken: "token",
            profileId: nil,
            forceRestart: true
        )
        XCTAssertGreaterThan(service.syncGenerationForTests, firstGeneration)
        service.cancelPendingSync()
        hold.allowFinish()
        await awaitSyncIdle(service)
    }

    @MainActor
    func testSlowRemoteRevokeStillBlocksSync() async {
        let service = await seedConnected("user-a")
        let holdRemote = CollectProbe()
        service.testRemoteRevokeHandler = {
            holdRemote.markEntered()
            await holdRemote.waitUntilReleasedOrCancelled()
        }
        let revokeTask = Task { await service.revokeConsent(userId: "user-a", accessToken: "token") }
        let enteredRemote = await awaitCollectEntered(holdRemote)
        XCTAssertTrue(enteredRemote)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        holdRemote.allowFinish()
        await revokeTask.value
        XCTAssertEqual(service.connectionState, .notConnected)
    }

    @MainActor
    func testRemoteRevokeFailureKeepsSyncBlocked() async {
        let service = await seedConnected("user-a")
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
    func testConsensedSyncAllowedByGate() async {
        let service = await seedConnected("user-a")
        let generation = service.syncGenerationForTests
        XCTAssertTrue(
            service.ensureSyncStillAuthorized(
                userId: "user-a",
                generation: generation,
                stage: "unit"
            )
        )
        service.cancelPendingSync()
        XCTAssertFalse(
            service.ensureSyncStillAuthorized(
                userId: "user-a",
                generation: generation,
                stage: "stale_generation"
            )
        )
    }

    @MainActor
    func testCoordinatorStartBlockedWithoutConsent() async {
        let service = await seedConnected("user-a")
        service.testRemoteRevokeHandler = {}
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        service.testCollectHandler = { ([], nil) }
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        await awaitSyncIdle(service)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
    }

    @MainActor
    func testReconnectRequiredAfterRevoke() async {
        let service = await seedConnected("user-a")
        service.testRemoteRevokeHandler = {}
        await service.revokeConsent(userId: "user-a", accessToken: "token")
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        service.startBackgroundHealthSync(userId: "user-a", accessToken: "token", profileId: nil)
        XCTAssertEqual(service.testUploadAttemptCount, 0)
        service.seedDurableConsentMarkersForTests(userId: "user-a")
        service.bindAccount(userId: "user-a")
        XCTAssertEqual(service.connectionState, .connected)
    }
}

final class AppSessionLifecycleTests: XCTestCase {
    @MainActor
    func testCancelLifecycleRemovesObserversAndCancelsStartup() {
        let session = AppSession()
        XCTAssertEqual(session.testRegisteredObserverCountForTests, 4)
        XCTAssertFalse(session.testStartupTaskIsCancelledForTests)
        session.cancelLifecycleForTests()
        XCTAssertEqual(session.testRegisteredObserverCountForTests, 0)
        XCTAssertTrue(session.testStartupTaskIsCancelledForTests)
    }

    @MainActor
    func testCancelLifecycleIsIdempotent() {
        let session = AppSession()
        session.cancelLifecycleForTests()
        session.cancelLifecycleForTests()
        XCTAssertEqual(session.testRegisteredObserverCountForTests, 0)
        XCTAssertTrue(session.testStartupTaskIsCancelledForTests)
    }
}
