import CoreLocation
import Foundation
import XCTest
@testable import HiAir

@MainActor
final class ProfileEnsureTests: XCTestCase {
    private var harness: ProfileEnsureTestHarness!

    override func setUp() async throws {
        try await super.setUp()
        APIClient.setAuthState(nil)
        APIClient.setAuthInvalidatedHandler(nil)
        APIInvalidURLDiagnostics.resetForTests()
        ProductAnalytics.testEventSink = nil
        harness = ProfileEnsureTestHarness()
        UITestMockAPIProtocol.isEnabled = true
        UITestMockAPIProtocol.reset()
    }

    override func tearDown() async throws {
        ProductAnalytics.testEventSink = nil
        harness?.apiClient.testForceListProfilesError = nil
        harness?.tearDown()
        harness = nil
        UITestMockAPIProtocol.isEnabled = false
        UITestMockAPIProtocol.reset()
        APIClient.setAuthState(nil)
        APIClient.setAuthInvalidatedHandler(nil)
        APIInvalidURLDiagnostics.resetForTests()
        try await super.tearDown()
    }

    func testReadyWhenProfileAlreadyPresent() async {
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = "existing"
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .ready)
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles"), 0)
        XCTAssertNotEqual(outcome.analyticsReason, "unknown")
    }

    func testNeedsAuthenticationWhenUnsigned() async {
        let session = harness.makeSession()
        session.profileId = ""
        session.userId = ""
        session.accessToken = ""
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsAuthentication)
        XCTAssertEqual(outcome.category, .auth)
        XCTAssertEqual(outcome.diagnosticCode, "PE_AUTH")
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("auth.session_expired"))
        XCTAssertFalse(session.lastProfileEnsureOutcome?.suggestsLocationRecovery ?? true)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testNeedsLocationWhenCoordsMissing() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 0
        session.longitude = 0
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsLocation)
        XCTAssertEqual(outcome.category, .location)
        XCTAssertEqual(outcome.diagnosticCode, "PE_LOC")
        XCTAssertEqual(session.lastProfileEnsurePhase, .locationGate)
        XCTAssertTrue(outcome.suggestsLocationRecovery)
        XCTAssertTrue(session.profileId.isEmpty)
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertNotNil(session.profileEnsureUserMessage)
        XCTAssertNotEqual(outcome.analyticsReason, "unknown")
    }

    func testCityLabelWithoutCoordinatesStillNeedsLocation() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.displayPlaceName = "Castelldefels"
        session.latitude = 0
        session.longitude = 0
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsLocation)
        XCTAssertTrue(outcome.suggestsLocationRecovery)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"), 0)
    }

    func testPermissionDeniedMapsToNeedsLocation() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 0
        session.longitude = 0
        let denied = DeniedLocationStub()
        let bootstrapped = await session.bootstrapLocationFromDevice(locationService: denied)
        XCTAssertFalse(bootstrapped)
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsLocation)
        XCTAssertTrue(outcome.suggestsLocationRecovery)
        XCTAssertEqual(session.l("profile.ensure.needs_location"), session.profileEnsureUserMessage)
    }

    func testCreatesProfileWhenLocationValid() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "profile-uitest-1")
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"), 1)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"), 1)
    }

    func testCreateSuccessWithDelayedListConsistency() async {
        // Create returns 500 (client saw failure) but recovery list finds the profile that landed.
        UITestMockAPIProtocol.reset(
            listProfiles: .json(200, object: []),
            createProfile: .json(500, object: ["detail": "lag"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        UITestMockAPIProtocol.responseDelayNanoseconds = 40_000_000
        async let outcomeTask = session.ensureProfileIdIfNeeded()
        for _ in 0..<300 {
            if UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST") >= 1 {
                UITestMockAPIProtocol.setRoute(
                    method: "GET",
                    path: "/api/profiles",
                    response: .json(
                        200,
                        object: [[
                            "id": "recovered-1",
                            "user_id": "user-1",
                            "persona_type": "adult",
                            "sensitivity_level": "medium",
                            "home_lat": 41.28,
                            "home_lon": 1.976,
                            "date_of_birth": NSNull(),
                            "age_years": NSNull(),
                        ]]
                    )
                )
                break
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        let outcome = await outcomeTask
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "recovered-1")
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertNotEqual(outcome.analyticsReason, "unknown")
    }

    func testUsesExistingListedProfile() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(
                200,
                object: [[
                    "id": "listed-1",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "listed-1")
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"), 0)
    }

    func testUnauthorizedExpiresSession() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(401, object: ["detail": "unauthorized"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = ""
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsAuthentication)
        XCTAssertEqual(outcome.category, .auth)
        XCTAssertTrue(session.accessToken.isEmpty)
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testForbiddenSurfacesMessageWithoutLocationCTA() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(403, object: ["detail": "forbidden"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.forbidden))
        XCTAssertEqual(outcome.category, .auth)
        XCTAssertEqual(outcome.diagnosticCode, "PE_HTTP_403")
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.forbidden"))
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testUnavailable503() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(503, object: ["detail": "busy"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.unavailable))
        XCTAssertEqual(outcome.category, .server)
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.unavailable"))
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertTrue(outcome.suggestsNetworkRetry)
    }

    func testServer5xx() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(500, object: ["detail": "boom"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.server))
        XCTAssertEqual(outcome.diagnosticCode, "PE_HTTP_5XX")
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertTrue(outcome.suggestsNetworkRetry)
        XCTAssertNotEqual(outcome.analyticsReason, "unknown")
    }

    func testPremiumRequired402() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(200, object: []),
            createProfile: .json(402, object: ["detail": "Profile limit reached"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.premiumRequired))
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.premium_required"))
        XCTAssertTrue(session.profileId.isEmpty)
        XCTAssertFalse(outcome.suggestsLocationRecovery)
    }

    func testOfflineMapsViaURLError() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.failNextWithURLError = .notConnectedToInternet
        UITestMockAPIProtocol.failURLErrorPathSubstring = "/api/profiles"
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.offline))
        XCTAssertEqual(outcome.category, .network)
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.offline"))
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertTrue(outcome.suggestsNetworkRetry)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testTimeoutMapsToOffline() async {
        UITestMockAPIProtocol.reset()
        UITestMockAPIProtocol.failNextWithURLError = .timedOut
        UITestMockAPIProtocol.failURLErrorPathSubstring = "/api/profiles"
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.offline))
        XCTAssertNotEqual(outcome.analyticsReason, "unknown")
    }

    func testDecodeAndTransportMapping() {
        struct Dummy: Decodable { let value: Int }
        do {
            _ = try JSONDecoder().decode(Dummy.self, from: Data("{}".utf8))
            XCTFail("expected decode error")
        } catch {
            let mapped = ProfileEnsureMapper.outcome(for: error)
            XCTAssertEqual(mapped, .failure(.decode))
            XCTAssertEqual(mapped.category, .decode)
            XCTAssertEqual(mapped.messageKey, "profile.ensure.decode")
            XCTAssertFalse(mapped.suggestsLocationRecovery)
            let props = ProfileEnsureMapper.analyticsProperties(for: error, outcome: mapped, phase: .list)
            XCTAssertEqual(props["error_type"], "decode")
            XCTAssertEqual(props["phase"], "list")
            XCTAssertEqual(props["diagnostic_code"], "PE_DECODE")
            XCTAssertNotEqual(props["reason"], "unknown")
        }

        let cancelled = ProfileEnsureMapper.outcome(for: URLError(.cancelled))
        XCTAssertEqual(cancelled, .failure(.cancelled))
        XCTAssertEqual(cancelled.category, .cancelled)
        XCTAssertFalse(cancelled.suggestsLocationRecovery)
        XCTAssertFalse(cancelled.suggestsNetworkRetry)

        let tls = ProfileEnsureMapper.outcome(for: URLError(.secureConnectionFailed))
        XCTAssertEqual(tls, .failure(.transport))
        XCTAssertFalse(tls.suggestsLocationRecovery)

        let invalid = ProfileEnsureMapper.outcome(for: APIError.invalidResponse)
        XCTAssertEqual(invalid, .failure(.transport))
    }

    func testCancellationDoesNotSurfaceAsNetworkError() async {
        UITestMockAPIProtocol.reset()
        UITestMockAPIProtocol.failNextWithURLError = .cancelled
        UITestMockAPIProtocol.failURLErrorPathSubstring = "/api/profiles"
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.cancelled))
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.cancelled"))
        XCTAssertFalse(outcome.suggestsLocationRecovery)
        XCTAssertNotEqual(session.profileEnsureUserMessage, session.l("profile.ensure.failed"))
        XCTAssertNotEqual(session.profileEnsureUserMessage, session.l("profile.ensure.offline"))
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testInvalidProfileJSONMapsToTransportViaInvalidResponse() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .raw(200, body: Data("<html>nope</html>".utf8), contentType: "text/html")
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .failure(.transport))
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.transport"))
        XCTAssertTrue(session.profileId.isEmpty)
        XCTAssertFalse(outcome.suggestsLocationRecovery)
    }

    func testSingleFlightDedupesConcurrentCalls() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        async let first = session.ensureProfileIdIfNeeded()
        async let second = session.ensureProfileIdIfNeeded()
        let a = await first
        let b = await second
        XCTAssertEqual(a, .ready)
        XCTAssertEqual(b, .ready)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"), 1)
    }

    func testPrepareThenEnsureDoesNotDoubleCreate() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let prepared = await session.prepareSessionForDataFetch(locationService: ImmediateCoordsLocationStub())
        XCTAssertTrue(prepared.profileReady)
        let postsAfterPrepare = UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST")
        XCTAssertEqual(postsAfterPrepare, 1)
        // Simulate Dashboard reload with skip — second ensure must be idempotent (no new POST).
        let again = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(again, .ready)
        XCTAssertEqual(UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"), 1)
    }

    func testDoubleTapRetryAfterFailureStartsOneNewRequest() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(503, object: ["detail": "busy"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let failed = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(failed, .failure(.unavailable))
        XCTAssertFalse(session.isEnsuringProfile)
        let getsAfterFail = UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET")

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "listed-after-retry",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        // Explicit Retry opens a new cycle (automatic post-failure ensure is memoized).
        session.beginExplicitProfileEnsureCycle()
        async let r1 = session.ensureProfileIdIfNeeded()
        async let r2 = session.ensureProfileIdIfNeeded()
        let a = await r1
        let b = await r2
        XCTAssertEqual(a, .ready)
        XCTAssertEqual(b, .ready)
        XCTAssertEqual(session.profileId, "listed-after-retry")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            getsAfterFail + 1,
            "retry double-tap must single-flight one new GET"
        )
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertNil(session.profileEnsureUserMessage)
    }

    func testLoadingResetsAfterFailureAndSuccess() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(503, object: ["detail": "busy"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertFalse(session.isEnsuringProfile)

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "ok-1",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        session.beginExplicitProfileEnsureCycle()
        let ok = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(ok, .ready)
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertEqual(session.lastProfileEnsureOutcome, .ready)
    }

    func testLocalizationRUAndENForEnsureKeysAndRecoveryCTA() {
        XCTAssertEqual(HiAirL10n.t("profile.ensure.needs_location", lang: "ru").contains("геолокац"), true)
        XCTAssertEqual(HiAirL10n.t("profile.ensure.needs_location", lang: "en").lowercased().contains("location"), true)
        XCTAssertEqual(HiAirL10n.t("location.retry", lang: "ru"), "Повторить")
        XCTAssertEqual(HiAirL10n.t("location.retry", lang: "en"), "Retry")
        XCTAssertEqual(HiAirL10n.t("profile.ensure.retry", lang: "ru"), "Повторить")
        XCTAssertEqual(HiAirL10n.t("profile.ensure.retry", lang: "en"), "Retry")
        XCTAssertEqual(HiAirL10n.t("auth.sign_in", lang: "ru"), "Войти")
        XCTAssertEqual(HiAirL10n.t("auth.sign_in", lang: "en"), "Sign in")
        XCTAssertFalse(HiAirL10n.t("profile.ensure.offline", lang: "ru").isEmpty)
        XCTAssertFalse(HiAirL10n.t("profile.ensure.offline", lang: "en").isEmpty)
        XCTAssertTrue(HiAirL10n.t("profile.ensure.unavailable", lang: "ru").contains("временно"))
        XCTAssertTrue(HiAirL10n.t("profile.ensure.unavailable", lang: "en").lowercased().contains("unavailable"))
    }

    func testLocationRecoveryOnlyForNeedsLocationCategory() {
        XCTAssertTrue(ProfileEnsureOutcome.needsLocation.suggestsLocationRecovery)
        XCTAssertEqual(ProfileEnsureOutcome.needsLocation.category, .location)
        XCTAssertFalse(ProfileEnsureOutcome.failure(.unavailable).suggestsLocationRecovery)
        XCTAssertEqual(ProfileEnsureOutcome.failure(.unavailable).category, .server)
        XCTAssertTrue(ProfileEnsureOutcome.failure(.unavailable).suggestsNetworkRetry)
        XCTAssertFalse(ProfileEnsureOutcome.failure(.offline).suggestsLocationRecovery)
        XCTAssertTrue(ProfileEnsureOutcome.failure(.offline).suggestsNetworkRetry)
        XCTAssertFalse(ProfileEnsureOutcome.failure(.cancelled).suggestsLocationRecovery)
        XCTAssertFalse(ProfileEnsureOutcome.needsAuthentication.suggestsLocationRecovery)
    }

    // MARK: - Foreground cycle: ensure-once (TF 159 P1)

    /// Mirrors Dashboard `.onReceive(.profileLocationDidUpdate)` ensure decision.
    @discardableResult
    private func simulateDashboardProfileLocationReload(
        session: AppSession,
        notification: Notification
    ) async -> ProfileEnsureOutcome? {
        let skip = ProfileLocationUpdateContext.skipProfileEnsure(
            from: notification,
            currentUserId: session.userId
        )
        guard !skip, session.profileId.isEmpty else { return nil }
        return await session.ensureProfileIdIfNeeded()
    }

    func testForegroundEnsureFailureDoesNotDoubleEnsureViaLocationNotification() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(500, object: ["detail": "boom"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        // Avoid async place-resolve noise during prepare; P1 is ensure ownership.
        session.displayPlaceName = "Castelldefels"

        var sources: [ProfileLocationUpdateContext.Source] = []
        var secondEnsureFired = false
        let observer = NotificationCenter.default.addObserver(
            forName: .profileLocationDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            let context = notification.object as? ProfileLocationUpdateContext
            if let source = context?.source {
                sources.append(source)
            }
            XCTAssertEqual(context?.userId, "user-1")
            XCTAssertTrue(
                ProfileLocationUpdateContext.skipProfileEnsure(
                    from: notification,
                    currentUserId: "user-1"
                ),
                "post-prepare location notifications must skip ensure for the owning user"
            )
            Task { @MainActor in
                let outcome = await self.simulateDashboardProfileLocationReload(
                    session: session,
                    notification: notification
                )
                if outcome != nil {
                    secondEnsureFired = true
                }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await session.refreshOnForeground(locationService: ImmediateCoordsLocationStub())
        // Allow notification handler tasks to settle.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(sources.contains(.foregroundRefresh))
        XCTAssertFalse(secondEnsureFired, "Dashboard must not start a second ensure after foreground prepare")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1,
            "exactly one list ensure in the foreground cycle"
        )
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.server))
        XCTAssertEqual(session.lastProfileEnsurePhase, .list)
        XCTAssertEqual(session.lastProfileEnsureOutcome?.diagnosticCode, "PE_HTTP_5XX")
        XCTAssertNotEqual(session.lastProfileEnsureOutcome?.diagnosticCode, "PE_NET_TRANSPORT")
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.failed"))
    }

    func testForegroundEnsureSuccessNotificationReloadsWithoutSecondEnsure() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(
                200,
                object: [[
                    "id": "listed-1",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"

        var sawForegroundRefresh = false
        var notificationEnsureAttempts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .profileLocationDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            if (notification.object as? ProfileLocationUpdateContext)?.source == .foregroundRefresh {
                sawForegroundRefresh = true
            }
            Task { @MainActor in
                if await self.simulateDashboardProfileLocationReload(
                    session: session,
                    notification: notification
                ) != nil {
                    notificationEnsureAttempts += 1
                }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await session.refreshOnForeground(locationService: ImmediateCoordsLocationStub())
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(sawForegroundRefresh, "downstream dashboard reload signal must still fire")
        XCTAssertEqual(notificationEnsureAttempts, 0)
        XCTAssertEqual(session.profileId, "listed-1")
        XCTAssertEqual(session.lastProfileEnsureOutcome, .ready)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"),
            0
        )
    }

    func testStaleForegroundRefreshNotificationDoesNotSkipEnsureAfterAccountSwitch() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(
                200,
                object: [[
                    "id": "listed-b",
                    "user_id": "user-b",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        let session = harness.makeSession()
        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-a",
                email: "a@example.com",
                accessToken: "token-a",
                refreshToken: "refresh-a"
            )
        )
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"
        session.profileId = ""

        // Stale post attributed to user-a, delivered after switch to user-b.
        let staleNotification = Notification(
            name: .profileLocationDidUpdate,
            object: ProfileLocationUpdateContext(source: .foregroundRefresh, userId: "user-a")
        )

        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-b",
                email: "b@example.com",
                accessToken: "token-b",
                refreshToken: "refresh-b"
            )
        )
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"
        XCTAssertTrue(session.profileId.isEmpty)

        XCTAssertFalse(
            ProfileLocationUpdateContext.skipProfileEnsure(
                from: staleNotification,
                currentUserId: session.userId
            ),
            "foreign/stale attribution must not suppress ensure for the live session"
        )

        let outcome = await simulateDashboardProfileLocationReload(
            session: session,
            notification: staleNotification
        )
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "listed-b")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testAbandonedForegroundPrepareDoesNotSkipEnsureForReplacementAccount() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.responseDelayNanoseconds = 200_000_000
        let session = harness.makeSession()
        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-a",
                email: "a@example.com",
                accessToken: "token-a",
                refreshToken: "refresh-a"
            )
        )
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"
        session.profileId = ""

        var postedContexts: [ProfileLocationUpdateContext] = []
        let observer = NotificationCenter.default.addObserver(
            forName: .profileLocationDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            if let context = notification.object as? ProfileLocationUpdateContext {
                postedContexts.append(context)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        async let abandonedRefresh: Void = session.refreshOnForeground(
            locationService: ImmediateCoordsLocationStub()
        )
        // Let user-a prepare/ensure start under delay.
        for _ in 0..<100 {
            if session.isEnsuringProfile { break }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-b",
                email: "b@example.com",
                accessToken: "token-b",
                refreshToken: "refresh-b"
            )
        )
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"
        session.profileId = ""
        session.resetForegroundRefreshDebounceForTests()

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "listed-b",
                    "user_id": "user-b",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        UITestMockAPIProtocol.responseDelayNanoseconds = 0

        await abandonedRefresh
        // Abandoned user-a foreground must not post a skip-eligible notification for user-b.
        XCTAssertFalse(
            postedContexts.contains {
                $0.source == .foregroundRefresh && $0.userId == "user-b"
            }
        )
        XCTAssertFalse(
            postedContexts.contains {
                $0.source == .foregroundRefresh && $0.userId == "user-a"
            },
            "cancelled/abandoned owner must not emit foreground skip notification"
        )

        let prepared = await session.prepareSessionForDataFetch(
            locationService: ImmediateCoordsLocationStub()
        )
        XCTAssertTrue(prepared.profileReady)
        XCTAssertEqual(session.profileId, "listed-b")
        // Replacement account must own a real ensure (not coalesce onto abandoned prepare).
        XCTAssertGreaterThanOrEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testIndependentCoordinateChangeStillEnsuresOnce() async {
        // Callers audit: independent location updates go through locationRevision /
        // applyDeviceLocation → syncProfileLocationIfNeeded → ensure when profile empty.
        // `.profileLocationDidUpdate` is not the owner of that ensure.
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 0
        session.longitude = 0

        var notificationEnsureAttempts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .profileLocationDidUpdate,
            object: nil,
            queue: nil
        ) { notification in
            Task { @MainActor in
                if await self.simulateDashboardProfileLocationReload(
                    session: session,
                    notification: notification
                ) != nil {
                    notificationEnsureAttempts += 1
                }
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let applied = await session.applyDeviceLocation(lat: 41.28, lon: 1.976)
        XCTAssertTrue(applied)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertFalse(session.profileId.isEmpty)
        XCTAssertEqual(notificationEnsureAttempts, 0, "notification path must not add a second ensure")
        // One ensure from syncProfileLocationIfNeeded (list→create).
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"),
            1
        )
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testNewForegroundCycleCanEnsureAgainWithoutWallClockWait() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(500, object: ["detail": "boom"])
        )
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        await session.refreshOnForeground(locationService: ImmediateCoordsLocationStub())
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.server))

        // Ownership reset for a new cycle — not a wall-clock debounce workaround for double-ensure.
        session.resetForegroundRefreshDebounceForTests()
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "listed-cycle-2",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        await session.refreshOnForeground(locationService: ImmediateCoordsLocationStub())
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2,
            "a later real refresh-cycle may run a new ensure"
        )
        XCTAssertEqual(session.profileId, "listed-cycle-2")
        XCTAssertEqual(session.lastProfileEnsureOutcome, .ready)
    }

    // MARK: - TF164 triple-trigger (cold launch Tab graph)

    /// Mirrors Dashboard prepare + sibling Tab `.task` ensures after first terminal
    /// (physical TF164: 3× `profile_ensure_failed` / `invalid_url` / `list`).
    private func simulateTF164ColdLaunchEnsureGraph(session: AppSession) async {
        let location = ImmediateCoordsLocationStub()
        // Controllable scheduler: yield between triggers (no wall-clock sleep).
        await session.prepareSessionForDataFetch(locationService: location)
        await Task.yield()
        // DailyPlannerView `.task` when profile empty
        if session.profileId.isEmpty {
            _ = await session.ensureProfileIdIfNeeded()
        }
        await Task.yield()
        // InsightsView `.task` when profile empty
        if session.profileId.isEmpty {
            _ = await session.ensureProfileIdIfNeeded()
        }
        await Task.yield()
        // Dashboard locationRevision reload (automatic — must not open a new cycle)
        if session.profileId.isEmpty {
            _ = await session.ensureProfileIdIfNeeded()
        }
    }

    func testTF164TripleTriggerInvalidURLSingleEnsurePerCycle() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        harness.apiClient.testForceListProfilesError = APIError.invalidURL
        APIInvalidURLDiagnostics.record(
            source: .supabaseBaseMissing,
            hasScheme: false,
            hasHost: false,
            configSource: "plist"
        )

        var failedEvents: [[String: String]] = []
        ProductAnalytics.testEventSink = { name, props in
            if name == "profile_ensure_failed" {
                failedEvents.append(props)
            }
        }

        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"

        await simulateTF164ColdLaunchEnsureGraph(session: session)

        XCTAssertEqual(
            session.profileEnsureCycleAttemptCount,
            1,
            "one underlying ensure attempt for the cold-launch cycle"
        )
        XCTAssertEqual(failedEvents.count, 1, "one terminal profile_ensure_failed emission")
        XCTAssertEqual(failedEvents.first?["diagnostic_code"], "PE_NET_TRANSPORT")
        XCTAssertEqual(failedEvents.first?["error_type"], "invalid_url")
        XCTAssertEqual(failedEvents.first?["phase"], "list")
        XCTAssertEqual(failedEvents.first?["reason"], "transport")
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.transport))
        XCTAssertEqual(session.lastProfileEnsurePhase, .list)
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.transport"))
        XCTAssertTrue(session.lastProfileEnsureOutcome?.suggestsNetworkRetry == true)
        XCTAssertFalse(session.lastProfileEnsureOutcome?.suggestsLocationRecovery == true)
        XCTAssertNotEqual(session.lastProfileEnsureOutcome?.analyticsReason, "unknown")
    }

    func testTF164TripleTriggerSuccessSingleEnsurePerCycle() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(
                200,
                object: [[
                    "id": "listed-tf164",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        var failedCount = 0
        ProductAnalytics.testEventSink = { name, _ in
            if name == "profile_ensure_failed" { failedCount += 1 }
        }
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"

        await simulateTF164ColdLaunchEnsureGraph(session: session)

        XCTAssertEqual(session.profileId, "listed-tf164")
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        XCTAssertEqual(failedCount, 0)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
        XCTAssertEqual(session.lastProfileEnsureOutcome, .ready)
    }

    func testTF164TripleTriggerHTTP500SingleEnsurePerCycle() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        var failedCount = 0
        ProductAnalytics.testEventSink = { name, _ in
            if name == "profile_ensure_failed" { failedCount += 1 }
        }
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"

        await simulateTF164ColdLaunchEnsureGraph(session: session)

        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        XCTAssertEqual(failedCount, 1)
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.server))
        XCTAssertEqual(session.lastProfileEnsureOutcome?.diagnosticCode, "PE_HTTP_5XX")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testExplicitRetryAfterFailureCreatesSecondLegitimateAttempt() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        await simulateTF164ColdLaunchEnsureGraph(session: session)
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "retry-ok",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        session.beginExplicitProfileEnsureCycle()
        let retry = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(retry, .ready)
        XCTAssertEqual(session.profileId, "retry-ok")
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1, "new cycle resets attempt counter")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2
        )
    }

    /// Planner refresh / Insights refresh / Dashboard recompute must call
    /// `beginExplicitProfileEnsureCycle()` before ensure when `profileId` is empty —
    /// otherwise a prior terminal failure is memoized and user taps cannot recover.
    func testUserTriggeredRefreshAfterFailureCreatesSecondLegitimateAttempt() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)

        // Without an explicit cycle, sibling refresh would stay memoized.
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1,
            "memoized terminal must not start a second network list"
        )

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "user-refresh-ok",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        // Same contract as Planner/Insights/Dashboard user-triggered refresh buttons.
        session.beginExplicitProfileEnsureCycle()
        let retry = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(retry, .ready)
        XCTAssertEqual(session.profileId, "user-refresh-ok")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2
        )
    }

    func testNewLocationRevisionAfterTerminalCreatesNewAttempt() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        session.displayPlaceName = "Castelldefels"

        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(200, object: [])
        )
        // Post-terminal device move — legitimate new cycle.
        _ = await session.applyDeviceLocation(lat: 41.39, lon: 2.17)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2,
            "new location revision after terminal may ensure again"
        )
    }

    func testSameUserTokenRefreshDoesNotDuplicateEnsure() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(
                200,
                object: [[
                    "id": "tok-1",
                    "user_id": "user-1",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        UITestMockAPIProtocol.responseDelayNanoseconds = 60_000_000
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token-old"
        session.refreshToken = "refresh"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        async let ensure: ProfileEnsureOutcome = session.ensureProfileIdIfNeeded()
        await Task.yield()
        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-1",
                email: "a@example.com",
                accessToken: "token-new",
                refreshToken: "refresh-new"
            )
        )
        let outcome = await ensure
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "tok-1")
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testAccountSwitchDoesNotReuseStaleCycleResult() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-a"
        session.accessToken = "token-a"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.server))

        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(
                200,
                object: [[
                    "id": "user-b-profile",
                    "user_id": "user-b",
                    "persona_type": "adult",
                    "sensitivity_level": "medium",
                    "home_lat": 41.28,
                    "home_lon": 1.976,
                    "date_of_birth": NSNull(),
                    "age_years": NSNull(),
                ]]
            )
        )
        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-b",
                email: "b@example.com",
                accessToken: "token-b",
                refreshToken: "refresh-b"
            )
        )
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "user-b-profile")
        XCTAssertNotEqual(session.lastProfileEnsureOutcome, .failure(.server))
    }

    func testDashboardSuccessTelemetryDoesNotClearEnsureFailureStickyUI() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        await simulateTF164ColdLaunchEnsureGraph(session: session)
        let sticky = session.lastProfileEnsureOutcome
        XCTAssertEqual(sticky, .failure(.server))
        // Dashboard may still emit refresh_succeeded for air metrics — ensure sticky must remain.
        StartupDiagnostics.track(
            "dashboard_refresh_succeeded",
            success: true,
            profilePresent: false
        )
        XCTAssertEqual(session.lastProfileEnsureOutcome, sticky)
        XCTAssertTrue(session.profileEnsureUserMessage != nil)
    }

    func testSupabaseEmptyEnvDoesNotShadowPlistURL() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: ["SUPABASE_URL": "   ", "SUPABASE_ANON_KEY": ""],
            infoDictionary: [
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "plist")
        XCTAssertTrue(resolved.isValid)
        XCTAssertEqual(resolved.url?.host, "example.supabase.co")
        XCTAssertEqual(resolved.url?.scheme, "https")
        XCTAssertEqual(resolved.anonKey, "plist-anon")
    }

    func testSupabaseAbsentEnvUsesPlistPair() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [:],
            infoDictionary: [
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "plist")
        XCTAssertTrue(resolved.isValid)
        XCTAssertEqual(resolved.anonKey, "plist-anon")
    }

    func testSupabaseEmptyStringEnvUsesPlistPair() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: ["SUPABASE_URL": ""],
            infoDictionary: [
                "SUPABASE_URL": "https://example.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "plist")
        XCTAssertTrue(resolved.isValid)
    }

    func testSupabaseValidEnvPairPreferredAtomically() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [
                "SUPABASE_URL": "https://env.supabase.co",
                "SUPABASE_ANON_KEY": "env-anon",
            ],
            infoDictionary: [
                "SUPABASE_URL": "https://plist.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "env")
        XCTAssertTrue(resolved.isValid)
        XCTAssertEqual(resolved.url?.host, "env.supabase.co")
        XCTAssertEqual(resolved.anonKey, "env-anon", "must not mix plist anon key with env URL")
    }

    func testSupabaseMalformedEnvFailsClosedWithoutPlistFallback() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [
                "SUPABASE_URL": "not-a-valid-url",
                "SUPABASE_ANON_KEY": "env-anon",
            ],
            infoDictionary: [
                "SUPABASE_URL": "https://plist.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "env")
        XCTAssertFalse(resolved.isValid)
        XCTAssertNil(resolved.url)
        XCTAssertNotEqual(resolved.url?.host, "plist.supabase.co")
    }

    func testSupabaseMalformedPlistFailsClosed() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [:],
            infoDictionary: [
                "SUPABASE_URL": "ftp://bad",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "plist")
        XCTAssertFalse(resolved.isValid)
        XCTAssertNil(resolved.url)
    }

    func testSupabaseEnvURLWithoutKeyIsInvalidPair() {
        let resolved = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [
                "SUPABASE_URL": "https://env.supabase.co",
            ],
            infoDictionary: [
                "SUPABASE_URL": "https://plist.supabase.co",
                "SUPABASE_ANON_KEY": "plist-anon",
            ]
        )
        XCTAssertEqual(resolved.configSource, "env")
        XCTAssertFalse(resolved.isValid, "env URL without env key must not borrow plist key")
        XCTAssertEqual(resolved.anonKey, "")
    }

    func testLegacyEmptyEnvShadowingProducesInvalidURLBeforeFixSemantics() {
        // Pre-fix: `env ?? plist ?? ""` treated empty env as present → URL(string:"") nil.
        let env = ""
        let plist = "https://example.supabase.co"
        let raw = env.isEmpty ? env : (plist) // illustrate empty-first bug when env key present as ""
        // Actual legacy used ?? so empty string env wins:
        let legacyRaw: String = {
            let e: String? = ""
            let p: String? = plist
            return e ?? p ?? ""
        }()
        XCTAssertEqual(legacyRaw, "")
        XCTAssertNil(URL(string: legacyRaw))
        _ = raw
        let fixed = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: ["SUPABASE_URL": "", "SUPABASE_ANON_KEY": "anon"],
            infoDictionary: [
                "SUPABASE_URL": plist,
                "SUPABASE_ANON_KEY": "anon",
            ]
        )
        XCTAssertTrue(fixed.isValid)
        XCTAssertEqual(fixed.configSource, "plist")
    }

    func testInvalidURLDiagnosticsNeverContainURLOrKeyMaterial() {
        APIInvalidURLDiagnostics.resetForTests()
        _ = SupabaseAuthService.resolveSupabaseConfiguration(
            environment: [
                "SUPABASE_URL": "https://secret.example/path?token=abc",
                "SUPABASE_ANON_KEY": "",
            ],
            infoDictionary: [:]
        )
        APIInvalidURLDiagnostics.record(
            source: .supabaseBaseMissing,
            hasScheme: true,
            hasHost: true,
            configSource: "env"
        )
        let props = ProfileEnsureMapper.analyticsProperties(
            for: APIError.invalidURL,
            outcome: .failure(.transport),
            phase: .list
        )
        let joined = props.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        XCTAssertFalse(joined.contains("secret.example"))
        XCTAssertFalse(joined.contains("token=abc"))
        XCTAssertFalse(joined.contains("https://"))
        XCTAssertEqual(props["error_type"], "invalid_url")
        XCTAssertEqual(props["url_source"], "supabase_base_missing")
        XCTAssertEqual(props["url_config_source"], "env")
        XCTAssertEqual(props["url_has_scheme"], "1")
        XCTAssertEqual(props["url_has_host"], "1")
    }

    func testNilSupabaseBaseThrowsInvalidURLOnAuthRefreshPath() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UITestMockAPIProtocol.self]
        let session = URLSession(configuration: config)
        let auth = SupabaseAuthService(
            urlSession: session,
            supabaseURL: nil,
            anonKey: "",
            redirectURI: "hiair://auth/callback"
        )
        APIClient.setAuthState(
            APIClient.AuthState(userId: "u1", accessToken: "a", refreshToken: "r")
        )
        defer { APIClient.setAuthState(nil) }
        do {
            _ = try await auth.refreshSession()
            XCTFail("expected invalidURL when supabase base missing")
        } catch let error as APIError {
            guard case .invalidURL = error else {
                return XCTFail("expected APIError.invalidURL, got \(error)")
            }
            let outcome = ProfileEnsureMapper.outcome(for: error)
            XCTAssertEqual(outcome, .failure(.transport))
            let props = ProfileEnsureMapper.analyticsProperties(
                for: error,
                outcome: outcome,
                phase: .list
            )
            XCTAssertEqual(props["error_type"], "invalid_url")
            XCTAssertEqual(props["phase"], "list")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testLogoutClearsEnsureCycleMemo() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        XCTAssertEqual(session.lastProfileEnsureOutcome, .failure(.server))
        session.logout()
        XCTAssertNil(session.lastProfileEnsureOutcome)
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 0)
        // New sign-in must not reuse prior terminal.
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = "refresh"
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(200, object: [])
        )
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2
        )
    }

    func testRapidEnsureCallsAfterTerminalDoNotCreateNewAttempts() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "boom"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        await simulateTF164ColdLaunchEnsureGraph(session: session)
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        // Rapid view recreation / repeated .task — no new cycle.
        async let a = session.ensureProfileIdIfNeeded()
        async let b = session.ensureProfileIdIfNeeded()
        async let c = session.ensureProfileIdIfNeeded()
        _ = await (a, b, c)
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testCancellationDoesNotStoreTerminalNetworkMemo() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.responseDelayNanoseconds = 200_000_000
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let task = Task { await session.ensureProfileIdIfNeeded() }
        await Task.yield()
        session.logout() // cancels in-flight + clears cycle
        let outcome = await task.value
        // Cancellation / abandon must not sticky-write a network transport failure.
        XCTAssertNotEqual(outcome, .failure(.transport))
        XCTAssertNotEqual(outcome, .failure(.offline))
        XCTAssertNotEqual(session.lastProfileEnsureOutcome, .failure(.transport))
        XCTAssertNotEqual(session.lastProfileEnsureOutcome, .failure(.offline))
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 0)
    }

    func testStaleContextUserMismatchReensures() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(500, object: ["detail": "a"]))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(session.profileEnsureCycleAttemptCount, 1)

        session.userId = "user-2"
        session.accessToken = "token-2"
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/profiles",
            response: .json(200, object: [])
        )
        _ = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            2,
            "user mismatch must open a new cycle and re-ensure"
        )
    }

    func testConcurrentPrepareInSameCycleSingleFlightsEnsure() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.responseDelayNanoseconds = 80_000_000
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let location = ImmediateCoordsLocationStub()
        async let first = session.prepareSessionForDataFetch(locationService: location)
        async let second = session.prepareSessionForDataFetch(locationService: location)
        let a = await first
        let b = await second
        XCTAssertTrue(a.profileReady)
        XCTAssertTrue(b.profileReady)
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "POST"),
            1
        )
    }

    func testLegacyNilNotificationObjectDoesNotSkipEnsure() async {
        // Untyped posts (object nil) keep prior behavior — ensure still runs when profile empty.
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        UITestMockAPIProtocol.reset(
            listProfiles: .json(503, object: ["detail": "busy"])
        )
        let note = Notification(name: .profileLocationDidUpdate, object: nil)
        XCTAssertFalse(
            ProfileLocationUpdateContext.skipProfileEnsure(from: note, currentUserId: session.userId)
        )
        let outcome = await simulateDashboardProfileLocationReload(session: session, notification: note)
        XCTAssertEqual(outcome, .failure(.unavailable))
        XCTAssertEqual(
            UITestMockAPIProtocol.requestCount(matching: "/api/profiles", method: "GET"),
            1
        )
    }

    func testNormalizedPersonaAndSensitivity() {
        XCTAssertEqual(AppSession.normalizedPersona("ASTHMA"), "asthma")
        XCTAssertEqual(AppSession.normalizedPersona("general"), "adult")
        XCTAssertEqual(AppSession.normalizedSensitivity("HIGH"), "high")
        XCTAssertEqual(AppSession.normalizedSensitivity("weird"), "medium")
    }

    func testIdempotentSecondTapAfterReady() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let first = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(first, .ready)
        let before = UITestMockAPIProtocol.recordedRequests.count
        let second = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(second, .ready)
        XCTAssertEqual(UITestMockAPIProtocol.recordedRequests.count, before)
    }

    func testInstallAuthSessionClearsForeignProfileAndStaleError() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(503, object: ["detail": "busy"])
        )
        let session = harness.makeSession()
        session.userId = "user-a"
        session.accessToken = "token-a"
        session.refreshToken = "refresh-a"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976
        let failed = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(failed, .failure(.unavailable))
        XCTAssertNotNil(session.profileEnsureUserMessage)
        session.profileId = "profile-a"

        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-b",
                email: "b@example.com",
                accessToken: "token-b",
                refreshToken: "refresh-b"
            )
        )

        XCTAssertEqual(session.userId, "user-b")
        XCTAssertEqual(session.profileId, "")
        XCTAssertEqual(session.latitude, 0)
        XCTAssertEqual(session.longitude, 0)
        XCTAssertEqual(session.locationSource, .unknown)
        XCTAssertNil(session.displayPlaceName)
        XCTAssertNil(session.lastProfileEnsureOutcome)
        XCTAssertNil(session.profileEnsureUserMessage)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testSameUserTokenRotationDoesNotCancelInFlightEnsure() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.responseDelayNanoseconds = 200_000_000
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token-old"
        session.refreshToken = "refresh-old"
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        async let ensureOutcome = session.ensureProfileIdIfNeeded()
        var sawLoading = false
        for _ in 0..<200 {
            if session.isEnsuringProfile {
                sawLoading = true
                break
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(sawLoading)

        // Same-user refresh mid-ensure must not abandon bootstrap.
        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-1",
                email: "a@example.com",
                accessToken: "token-new",
                refreshToken: "refresh-new"
            )
        )
        let outcome = await ensureOutcome
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(session.profileId, "profile-uitest-1")
        XCTAssertEqual(session.accessToken, "token-new")
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testSameUserAuthInstallKeepsProfileId() async {
        let session = harness.makeSession()
        session.userId = "user-a"
        session.accessToken = "token-old"
        session.refreshToken = "refresh-old"
        session.profileId = "profile-a"

        session.installAuthSession(
            SupabaseAuthSession(
                userId: "user-a",
                email: "a@example.com",
                accessToken: "token-new",
                refreshToken: "refresh-new"
            )
        )

        XCTAssertEqual(session.profileId, "profile-a")
        XCTAssertNil(session.lastProfileEnsureOutcome)
    }

    func testLogoutAbandonsInFlightEnsureWithoutWritingProfile() async {
        UITestMockAPIProtocol.reset(listProfiles: .json(200, object: []))
        UITestMockAPIProtocol.responseDelayNanoseconds = 250_000_000
        let session = harness.makeSession()
        session.userId = "user-1"
        session.accessToken = "token"
        session.refreshToken = ""
        session.profileId = ""
        session.latitude = 41.28
        session.longitude = 1.976

        async let ensureOutcome = session.ensureProfileIdIfNeeded()
        var sawLoading = false
        for _ in 0..<200 {
            if session.isEnsuringProfile {
                sawLoading = true
                break
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        XCTAssertTrue(sawLoading, "expected ensure to enter loading before logout")

        session.logout()
        let outcome = await ensureOutcome

        XCTAssertTrue(session.profileId.isEmpty)
        XCTAssertNil(session.lastProfileEnsureOutcome)
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertFalse(outcome.isReady)
    }

    func testExpectedBranchesNeverEmitUnknownReason() {
        let cases: [ProfileEnsureOutcome] = [
            .ready,
            .needsAuthentication,
            .needsLocation,
            .failure(.unauthorized),
            .failure(.forbidden),
            .failure(.unavailable),
            .failure(.offline),
            .failure(.premiumRequired),
            .failure(.server),
            .failure(.decode),
            .failure(.transport),
            .failure(.cancelled),
        ]
        for outcome in cases {
            XCTAssertNotEqual(outcome.analyticsReason, "unknown", "\(outcome)")
            XCTAssertFalse(outcome.diagnosticCode.isEmpty)
            if case .needsLocation = outcome {
                XCTAssertTrue(outcome.suggestsLocationRecovery)
            } else {
                XCTAssertFalse(outcome.suggestsLocationRecovery, "\(outcome)")
            }
        }
    }
}

@MainActor
private final class DeniedLocationStub: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .denied
    var serviceState: LocationServiceState = .denied

    func refreshAuthorizationStatus() {}
    func requestWhenInUseAuthorization() {}
    func openAppSettings() {}

    func fetchCurrentLocation() async throws -> CLLocation {
        throw CLError(.denied)
    }
}

@MainActor
private final class ImmediateCoordsLocationStub: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var serviceState: LocationServiceState = .authorized

    func refreshAuthorizationStatus() {}
    func requestWhenInUseAuthorization() {}
    func openAppSettings() {}

    func fetchCurrentLocation() async throws -> CLLocation {
        CLLocation(latitude: 41.28, longitude: 1.976)
    }
}

@MainActor
private final class ProfileEnsureTestHarness {
    let suiteName: String
    let defaults: UserDefaults
    let credentials: InMemorySessionCredentialStore
    let ownership: SessionDurableOwnership
    let apiClient: APIClient

    init() {
        suiteName = "hiair.tests.profile.ensure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults
        credentials = InMemorySessionCredentialStore()
        ownership = SessionDurableOwnership()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UITestMockAPIProtocol.self]
        config.waitsForConnectivity = false
        let urlSession = URLSession(configuration: config)
        apiClient = APIClient(baseURL: URL(string: "https://uitest.local")!, session: urlSession)
    }

    func makeSession() -> AppSession {
        let session = AppSession(
            remoteSessionRevoker: NoopRemoteSessionRevoker(),
            defaults: defaults,
            credentials: credentials,
            durableOwnership: ownership,
            apiClient: apiClient
        )
        session.cancelLifecycleForTests()
        return session
    }

    func tearDown() {
        credentials.removeAll()
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class NoopRemoteSessionRevoker: AuthRemoteSessionRevoking {
    func revokeRemoteSession(accessToken: String) async {}
}
