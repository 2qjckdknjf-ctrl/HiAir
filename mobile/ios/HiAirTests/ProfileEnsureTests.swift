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
        harness = ProfileEnsureTestHarness()
        UITestMockAPIProtocol.isEnabled = true
        UITestMockAPIProtocol.reset()
    }

    override func tearDown() async throws {
        harness?.tearDown()
        harness = nil
        UITestMockAPIProtocol.isEnabled = false
        UITestMockAPIProtocol.reset()
        APIClient.setAuthState(nil)
        APIClient.setAuthInvalidatedHandler(nil)
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
