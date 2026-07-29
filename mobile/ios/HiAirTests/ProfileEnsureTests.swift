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
    }

    func testNeedsAuthenticationWhenUnsigned() async {
        let session = harness.makeSession()
        session.profileId = ""
        session.userId = ""
        session.accessToken = ""
        let outcome = await session.ensureProfileIdIfNeeded()
        XCTAssertEqual(outcome, .needsAuthentication)
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("auth.session_expired"))
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
        XCTAssertEqual(session.lastProfileEnsureOutcome, .needsLocation)
        XCTAssertTrue(session.profileId.isEmpty)
        XCTAssertFalse(session.isEnsuringProfile)
        XCTAssertNotNil(session.profileEnsureUserMessage)
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
        XCTAssertTrue(session.accessToken.isEmpty)
        XCTAssertNil(session.lastProfileEnsureOutcome)
        XCTAssertNil(session.profileEnsureUserMessage)
        XCTAssertFalse(session.isEnsuringProfile)
    }

    func testForbiddenSurfacesMessage() async {
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
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.forbidden"))
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
        XCTAssertEqual(session.profileEnsureUserMessage, session.l("profile.ensure.unavailable"))
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
    }

    func testOfflineMapsToOfflineFailure() async {
        UITestMockAPIProtocol.reset(
            listProfiles: .json(200, object: [])
        )
        // Force create path, then replace create with unreachable by clearing routes mid-flight is hard;
        // instead map URLError via mapper unit path:
        let mapped = ProfileEnsureMapper.outcome(for: URLError(.notConnectedToInternet))
        XCTAssertEqual(mapped, .failure(.offline))
        XCTAssertEqual(mapped.messageKey, "profile.ensure.offline")
    }

    func testDecodeAndTransportMapping() {
        struct Dummy: Decodable { let value: Int }
        do {
            _ = try JSONDecoder().decode(Dummy.self, from: Data("{}".utf8))
            XCTFail("expected decode error")
        } catch {
            let mapped = ProfileEnsureMapper.outcome(for: error)
            XCTAssertEqual(mapped, .failure(.decode))
            XCTAssertEqual(mapped.messageKey, "profile.ensure.decode")
            XCTAssertTrue(mapped.suggestsLocationRecovery)
            let props = ProfileEnsureMapper.analyticsProperties(for: error, outcome: mapped)
            XCTAssertEqual(props["error_type"], "decode")
        }

        let cancelled = ProfileEnsureMapper.outcome(for: URLError(.cancelled))
        XCTAssertEqual(cancelled, .failure(.cancelled))
        XCTAssertEqual(cancelled.messageKey, "profile.ensure.cancelled")

        let tls = ProfileEnsureMapper.outcome(for: URLError(.secureConnectionFailed))
        XCTAssertEqual(tls, .failure(.transport))
        XCTAssertEqual(tls.messageKey, "profile.ensure.transport")

        let invalid = ProfileEnsureMapper.outcome(for: APIError.invalidResponse)
        XCTAssertEqual(invalid, .failure(.transport))
    }

    func testNormalizedPersonaAndSensitivity() {
        XCTAssertEqual(AppSession.normalizedPersona("ASTHMA"), "asthma")
        XCTAssertEqual(AppSession.normalizedPersona("general"), "adult")
        XCTAssertEqual(AppSession.normalizedSensitivity("HIGH"), "high")
        XCTAssertEqual(AppSession.normalizedSensitivity("weird"), "medium")
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

    func testLocalizationRUAndENForEnsureKeys() {
        XCTAssertEqual(HiAirL10n.t("profile.ensure.needs_location", lang: "ru").contains("геолокац"), true)
        XCTAssertEqual(HiAirL10n.t("profile.ensure.needs_location", lang: "en").lowercased().contains("location"), true)
        XCTAssertEqual(HiAirL10n.t("profile.ensure.creating", lang: "ru").isEmpty, false)
        XCTAssertEqual(HiAirL10n.t("profile.ensure.creating", lang: "en").isEmpty, false)
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
