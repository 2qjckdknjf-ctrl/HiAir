import CoreLocation
import XCTest
@testable import HiAir

@MainActor
private final class ImmediateLocationStub: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var serviceState: LocationServiceState = .authorized
    var fetchCalls = 0

    func refreshAuthorizationStatus() {}
    func requestWhenInUseAuthorization() {}
    func openAppSettings() {}

    func fetchCurrentLocation() async throws -> CLLocation {
        fetchCalls += 1
        return CLLocation(latitude: 41.3874, longitude: 2.1686)
    }
}

final class AppSessionTests: XCTestCase {
    @MainActor
    override func tearDown() async throws {
        // Drain any AppSession instances created in the last test by forcing
        // deterministic observer/task teardown via a throwaway session pattern:
        // individual tests call cancelLifecycleForTests on their locals below.
        APIClient.setAuthInvalidatedHandler(nil)
        try await super.tearDown()
    }

    func testLocalizationFallbackUsesKeyForUnknownValue() {
        let value = HiAirL10n.t("non.existing.key", lang: "ru")
        XCTAssertEqual(value, "non.existing.key")
    }

    @MainActor
    func testAppSessionLogoutClearsAuthState() {
        let session = AppSession()
        session.userId = "user-1"
        session.accessToken = "access-token"
        session.refreshToken = "refresh-token"
        session.profileId = "profile-1"
        session.authNotice = "notice"
        session.isPremium = true

        session.logout()
        session.cancelLifecycleForTests()

        XCTAssertEqual(session.userId, "")
        XCTAssertEqual(session.accessToken, "")
        XCTAssertEqual(session.refreshToken, "")
        XCTAssertEqual(session.profileId, "")
        XCTAssertEqual(session.authNotice, "")
        XCTAssertFalse(session.isPremium)
    }

    @MainActor
    func testApplyEntitlementUnlocksPremium() {
        let session = AppSession()
        session.cancelLifecycleForTests()
        let entitlement = UserEntitlementResponse(
            userId: "user-1",
            plan: "premium",
            isPremium: true,
            maxProfiles: 6,
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

    @MainActor
    func testAppSessionFinishOnboardingSetsFlag() {
        let session = AppSession()
        session.cancelLifecycleForTests()
        session.onboardingCompleted = false
        session.checklistHidden = true

        session.finishOnboarding()

        XCTAssertTrue(session.onboardingCompleted)
        XCTAssertFalse(session.checklistHidden)
    }

    @MainActor
    func testPrepareSessionSingleFlightReturnsConsistentResult() async {
        let session = AppSession()
        session.cancelLifecycleForTests()
        session.userId = "user-prepare"
        // No access token → profile bootstrap skips network.
        session.accessToken = ""
        // Valid coords → skip device location bootstrap path.
        session.latitude = 41.3874
        session.longitude = 2.1686
        let location = ImmediateLocationStub()
        async let first = session.prepareSessionForDataFetch(locationService: location)
        async let second = session.prepareSessionForDataFetch(locationService: location)
        let a = await first
        let b = await second
        XCTAssertEqual(a.profileReady, b.profileReady)
        XCTAssertEqual(a.locationReady, b.locationReady)
        XCTAssertEqual(location.fetchCalls, 0)
    }

    @MainActor
    func testHasValidLocationRejectsNullIsland() {
        let session = AppSession()
        session.cancelLifecycleForTests()
        session.latitude = 0
        session.longitude = 0
        XCTAssertFalse(session.hasValidLocation)
        session.latitude = 41.39
        session.longitude = 2.17
        XCTAssertTrue(session.hasValidLocation)
    }
}

// MARK: - Logout remote revoke regressions (no real network)

@MainActor
private final class RecordingRemoteSessionRevoker: AuthRemoteSessionRevoking {
    private(set) var revokedTokens: [String] = []
    private(set) var revokeCallCount: Int = 0
    private var holdContinuation: CheckedContinuation<Void, Never>?
    private(set) var isHolding = false
    var holdBeforeRecord = false

    func revokeRemoteSession(accessToken: String) async {
        if holdBeforeRecord {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                isHolding = true
                holdContinuation = cont
            }
            isHolding = false
            holdContinuation = nil
        }
        revokeCallCount += 1
        revokedTokens.append(accessToken)
    }

    func waitUntilHolding(maxAttempts: Int = 400) async -> Bool {
        for _ in 0..<maxAttempts {
            if isHolding { return true }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        return isHolding
    }

    func releaseHold() {
        guard let cont = holdContinuation else { return }
        holdContinuation = nil
        cont.resume()
    }
}

/// Isolated in-memory credentials + UserDefaults + ownership for durable-store relaunch proofs.
/// Uses `InMemorySessionCredentialStore` so proofs stay deterministic under
/// `CODE_SIGNING_ALLOWED=NO` (real SecItem may silently reject unsigned writes).
@MainActor
private final class IsolatedSessionDurableHarness {
    let suiteName: String
    let defaults: UserDefaults
    let credentials: InMemorySessionCredentialStore
    let ownership: SessionDurableOwnership

    init() {
        suiteName = "hiair.tests.session.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults
        credentials = InMemorySessionCredentialStore()
        ownership = SessionDurableOwnership()
    }

    func makeSession(revoker: (any AuthRemoteSessionRevoking)? = nil) -> AppSession {
        let session = AppSession(
            remoteSessionRevoker: revoker,
            defaults: defaults,
            credentials: credentials,
            durableOwnership: ownership
        )
        session.cancelLifecycleForTests()
        return session
    }

    func tearDown() {
        credentials.removeAll()
        defaults.removePersistentDomain(forName: suiteName)
    }

    func peekAuth() -> (userId: String?, email: String?, access: String?, refresh: String?) {
        (
            credentials.getString(forKey: "session.userId"),
            credentials.getString(forKey: "session.email"),
            credentials.getString(forKey: "session.accessToken"),
            credentials.getString(forKey: "session.refreshToken")
        )
    }
}

final class AppSessionLogoutRemoteRevokeTests: XCTestCase {
    @MainActor
    override func tearDown() async throws {
        APIClient.setAuthState(nil)
        APIClient.setAuthInvalidatedHandler(nil)
        try await super.tearDown()
    }

    @MainActor
    private func installLocalSession(
        _ session: AppSession,
        userId: String,
        accessToken: String,
        refreshToken: String = "refresh",
        email: String = ""
    ) {
        session.installAuthSession(
            SupabaseAuthSession(
                userId: userId,
                email: email.isEmpty ? "\(userId)@example.com" : email,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        )
        APIClient.setAuthState(
            APIClient.AuthState(
                userId: userId,
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        )
    }

    @MainActor
    func testLogoutCapturesTokenClearsLocalAndRevokesExactlyOnce() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        let session = harness.makeSession(revoker: revoker)
        installLocalSession(session, userId: "user-a", accessToken: "bearer-a")
        session.isPremium = true

        session.logout()

        XCTAssertEqual(session.userId, "")
        XCTAssertEqual(session.accessToken, "")
        XCTAssertNil(APIClient.getAuthState())
        XCTAssertFalse(session.isPremium)
        let peeked = harness.peekAuth()
        XCTAssertNil(peeked.userId)
        XCTAssertNil(peeked.access)
        XCTAssertNil(peeked.refresh)

        await session.awaitRemoteRevokeForTests()
        XCTAssertEqual(revoker.revokeCallCount, 1)
        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])
    }

    @MainActor
    func testLogoutWithoutTokenSkipsNetworkAndDoesNotPostNilSession() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        let session = harness.makeSession(revoker: revoker)
        APIClient.setAuthState(nil)
        session.userId = "ghost"
        session.accessToken = ""
        session.refreshToken = ""

        var nilPosts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: nil
        ) { note in
            if note.object == nil {
                nilPosts += 1
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        session.logout()
        await session.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokeCallCount, 0)
        XCTAssertEqual(nilPosts, 0)
        XCTAssertEqual(session.userId, "")
    }

    @MainActor
    func testLateRemoteRevokeAfterAccountBLoginDoesNotClearAccountB() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        revoker.holdBeforeRecord = true
        let session = harness.makeSession(revoker: revoker)
        installLocalSession(session, userId: "user-a", accessToken: "bearer-a")

        session.logout()
        XCTAssertNil(APIClient.getAuthState())
        let holding = await revoker.waitUntilHolding()
        XCTAssertTrue(holding)

        // Account B signs in while A's remote revoke is still in flight.
        let accountB = SupabaseAuthSession(
            userId: "user-b",
            email: "b@example.com",
            accessToken: "bearer-b",
            refreshToken: "refresh-b"
        )
        session.installAuthSession(accountB)
        APIClient.setAuthState(
            APIClient.AuthState(
                userId: "user-b",
                accessToken: "bearer-b",
                refreshToken: "refresh-b"
            )
        )
        XCTAssertEqual(session.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")

        revoker.releaseHold()
        await session.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])
        XCTAssertEqual(session.userId, "user-b")
        XCTAssertEqual(session.accessToken, "bearer-b")
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        let peeked = harness.peekAuth()
        XCTAssertEqual(peeked.userId, "user-b")
        XCTAssertEqual(peeked.access, "bearer-b")
        XCTAssertEqual(peeked.refresh, "refresh-b")
    }

    @MainActor
    func testRepeatedLogoutDoesNotDuplicateRemoteRevokeOrTouchNewAccount() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        revoker.holdBeforeRecord = true
        let session = harness.makeSession(revoker: revoker)
        installLocalSession(session, userId: "user-a", accessToken: "bearer-a")

        session.logout()
        let holding = await revoker.waitUntilHolding()
        XCTAssertTrue(holding)
        session.logout()
        session.logout()
        XCTAssertEqual(revoker.revokeCallCount, 0, "still held — at most one in-flight")

        revoker.releaseHold()
        await session.awaitRemoteRevokeForTests()
        XCTAssertEqual(revoker.revokeCallCount, 1)
        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])

        revoker.holdBeforeRecord = false
        installLocalSession(session, userId: "user-b", accessToken: "bearer-b")
        session.logout()
        session.logout()
        await session.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokeCallCount, 2)
        XCTAssertEqual(revoker.revokedTokens, ["bearer-a", "bearer-b"])
        XCTAssertEqual(session.userId, "")
        XCTAssertNil(APIClient.getAuthState())
        let peeked = harness.peekAuth()
        XCTAssertNil(peeked.userId)
        XCTAssertNil(peeked.access)
    }

    @MainActor
    func testLogoutAlwaysClearsSharedHealthKitWithoutBypass() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        let session = harness.makeSession(revoker: revoker)
        installLocalSession(session, userId: "user-a", accessToken: "bearer-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.consentPersisted.user-a")
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted.user-a")
        HealthKitService.shared.prepareForUnitTests()
        HealthKitService.shared.seedDurableConsentMarkersForTests(userId: "user-a")
        HealthKitService.shared.bindAccount(userId: "user-a")
        XCTAssertEqual(HealthKitService.shared.connectionState, .connected)

        session.logout()
        await session.awaitRemoteRevokeForTests()

        XCTAssertEqual(HealthKitService.shared.connectionState, .notConnected)
        XCTAssertTrue(HealthKitService.shared.boundUserId.isEmpty)
        XCTAssertEqual(revoker.revokeCallCount, 1)
    }

    @MainActor
    func testStaleSessionLogoutRevokesOnlyLocalAAndPreservesGlobalAccountB() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        revoker.holdBeforeRecord = true

        let sessionA = harness.makeSession(revoker: revoker)
        installLocalSession(sessionA, userId: "user-a", accessToken: "bearer-a", refreshToken: "refresh-a")
        sessionA.isPremium = true

        // Newer AppSession B claims the same durable store and installs account B.
        let sessionB = harness.makeSession(revoker: revoker)
        installLocalSession(
            sessionB,
            userId: "user-b",
            accessToken: "bearer-b",
            refreshToken: "refresh-b",
            email: "b@example.com"
        )
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")

        sessionA.logout()

        XCTAssertEqual(sessionA.userId, "")
        XCTAssertEqual(sessionA.accessToken, "")
        XCTAssertFalse(sessionA.isPremium)
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")
        XCTAssertEqual(harness.peekAuth().refresh, "refresh-b")

        let holding = await revoker.waitUntilHolding()
        XCTAssertTrue(holding)
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")

        revoker.releaseHold()
        await sessionA.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokeCallCount, 1)
        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        XCTAssertEqual(APIClient.getAuthState()?.refreshToken, "refresh-b")
        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.peekAuth().email, "b@example.com")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")
        XCTAssertEqual(harness.peekAuth().refresh, "refresh-b")
    }

    @MainActor
    func testStaleLogoutPreservesDurableBAcrossRelaunchAndAccountScopedFields() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()

        let sessionA = harness.makeSession(revoker: revoker)
        installLocalSession(
            sessionA,
            userId: "user-a",
            accessToken: "bearer-a",
            refreshToken: "refresh-a",
            email: "a@example.com"
        )
        sessionA.profileId = "profile-a"
        sessionA.persona = "asthma"
        sessionA.latitude = 1.0
        sessionA.longitude = 2.0
        sessionA.checklistCompletedItems = ["item-a"]
        sessionA.preferredLanguage = "en"

        // B installed through real AppSession persistence path on the same store.
        let sessionB = harness.makeSession(revoker: revoker)
        installLocalSession(
            sessionB,
            userId: "user-b",
            accessToken: "bearer-b",
            refreshToken: "refresh-b",
            email: "b@example.com"
        )
        sessionB.profileId = "profile-b"
        sessionB.persona = "runner"
        sessionB.latitude = 41.39
        sessionB.longitude = 2.16
        sessionB.locationSource = .device
        sessionB.checklistCompletedItems = ["item-b"]
        sessionB.preferredLanguage = "es"

        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.profileId"), "profile-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.persona"), "runner")
        XCTAssertEqual(harness.defaults.double(forKey: "session.latitude"), 41.39, accuracy: 0.0001)
        XCTAssertEqual(harness.defaults.stringArray(forKey: "session.checklistCompletedItems"), ["item-b"])
        XCTAssertEqual(harness.defaults.string(forKey: "session.preferredLanguage"), "es")

        // Stale A still holds A in memory; logout must not wipe B durable state.
        XCTAssertEqual(sessionA.userId, "user-a")
        sessionA.logout()
        await sessionA.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.peekAuth().email, "b@example.com")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")
        XCTAssertEqual(harness.peekAuth().refresh, "refresh-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.profileId"), "profile-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.persona"), "runner")
        XCTAssertEqual(harness.defaults.double(forKey: "session.latitude"), 41.39, accuracy: 0.0001)
        XCTAssertEqual(harness.defaults.double(forKey: "session.longitude"), 2.16, accuracy: 0.0001)
        XCTAssertEqual(harness.defaults.stringArray(forKey: "session.checklistCompletedItems"), ["item-b"])
        XCTAssertEqual(harness.defaults.string(forKey: "session.preferredLanguage"), "es")
        XCTAssertEqual(sessionB.userId, "user-b")
        XCTAssertEqual(sessionB.profileId, "profile-b")

        // Fresh AppSession (relaunch) restores B intact from durable store.
        APIClient.setAuthState(nil)
        let relaunched = harness.makeSession(revoker: revoker)
        XCTAssertEqual(relaunched.userId, "user-b")
        XCTAssertEqual(relaunched.email, "b@example.com")
        XCTAssertEqual(relaunched.accessToken, "bearer-b")
        XCTAssertEqual(relaunched.refreshToken, "refresh-b")
        XCTAssertEqual(relaunched.profileId, "profile-b")
        XCTAssertEqual(relaunched.persona, "runner")
        XCTAssertEqual(relaunched.latitude, 41.39, accuracy: 0.0001)
        XCTAssertEqual(relaunched.longitude, 2.16, accuracy: 0.0001)
        XCTAssertEqual(relaunched.checklistCompletedItems, ["item-b"])
        XCTAssertEqual(relaunched.preferredLanguage, "es")
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        XCTAssertEqual(APIClient.getAuthState()?.refreshToken, "refresh-b")
    }

    @MainActor
    func testOwningLogoutDeletesDurableCredentialsAndFreshSessionIsUnauthenticated() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()
        let session = harness.makeSession(revoker: revoker)
        installLocalSession(
            session,
            userId: "user-a",
            accessToken: "bearer-a",
            refreshToken: "refresh-a",
            email: "a@example.com"
        )
        session.profileId = "profile-a"
        session.latitude = 10
        session.longitude = 20

        XCTAssertEqual(harness.peekAuth().userId, "user-a")

        session.logout()
        await session.awaitRemoteRevokeForTests()

        XCTAssertEqual(revoker.revokedTokens, ["bearer-a"])
        XCTAssertNil(APIClient.getAuthState())
        let peeked = harness.peekAuth()
        XCTAssertNil(peeked.userId)
        XCTAssertNil(peeked.email)
        XCTAssertNil(peeked.access)
        XCTAssertNil(peeked.refresh)
        XCTAssertNil(harness.defaults.string(forKey: "session.profileId"))
        XCTAssertEqual(harness.defaults.double(forKey: "session.latitude"), 0.0, accuracy: 0.0001)

        let fresh = harness.makeSession(revoker: revoker)
        XCTAssertEqual(fresh.userId, "")
        XCTAssertEqual(fresh.accessToken, "")
        XCTAssertEqual(fresh.refreshToken, "")
        XCTAssertEqual(fresh.email, "")
        XCTAssertEqual(fresh.profileId, "")
        XCTAssertNil(APIClient.getAuthState())
    }

    @MainActor
    func testInstallAuthSessionTransfersDurableOwnershipAndStaleALosesMutationRights() async {
        let harness = IsolatedSessionDurableHarness()
        defer { harness.tearDown() }
        let revoker = RecordingRemoteSessionRevoker()

        let sessionA = harness.makeSession(revoker: revoker)
        installLocalSession(
            sessionA,
            userId: "user-a",
            accessToken: "bearer-a",
            refreshToken: "refresh-a",
            email: "a@example.com"
        )
        sessionA.profileId = "profile-a"
        sessionA.persona = "asthma"
        let generationAfterA = harness.ownership.generation
        XCTAssertEqual(harness.ownership.ownerUserId, "user-a")
        XCTAssertEqual(harness.peekAuth().userId, "user-a")
        XCTAssertEqual(harness.peekAuth().access, "bearer-a")

        // Newer authenticated account B claims durable ownership via installAuthSession.
        let sessionB = harness.makeSession(revoker: revoker)
        installLocalSession(
            sessionB,
            userId: "user-b",
            accessToken: "bearer-b",
            refreshToken: "refresh-b",
            email: "b@example.com"
        )
        sessionB.profileId = "profile-b"
        sessionB.persona = "runner"

        XCTAssertGreaterThan(harness.ownership.generation, generationAfterA)
        XCTAssertEqual(harness.ownership.ownerUserId, "user-b")
        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.profileId"), "profile-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.persona"), "runner")

        // Stale A still has A credentials in memory but must not mutate durable B.
        XCTAssertEqual(sessionA.userId, "user-a")
        sessionA.profileId = "profile-stolen"
        sessionA.persona = "child"
        sessionA.accessToken = "bearer-stolen"
        sessionA.refreshToken = "refresh-stolen"
        sessionA.email = "stolen@example.com"

        XCTAssertEqual(harness.ownership.ownerUserId, "user-b")
        XCTAssertEqual(harness.peekAuth().userId, "user-b")
        XCTAssertEqual(harness.peekAuth().email, "b@example.com")
        XCTAssertEqual(harness.peekAuth().access, "bearer-b")
        XCTAssertEqual(harness.peekAuth().refresh, "refresh-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.profileId"), "profile-b")
        XCTAssertEqual(harness.defaults.string(forKey: "session.persona"), "runner")
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
    }
}
