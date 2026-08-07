import XCTest
@testable import HiAir

/// Captures Settings-owned wearable consent DELETE calls (the premature remote path).
private final class SettingsConsentRevokeURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var _consentDeleteCount = 0
    private static var _requests: [(method: String, path: String)] = []

    static var consentDeleteCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _consentDeleteCount
    }

    static var requests: [(method: String, path: String)] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _consentDeleteCount = 0
        _requests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self._requests.append((method, path))
        if method == "DELETE", path.hasSuffix("/api/v1/wearables/consent") {
            Self._consentDeleteCount += 1
        }
        Self.lock.unlock()

        let body = Data(#"{"ok":true}"#.utf8)
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://settings-revoke.test/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Regression: Settings disconnect must not remote-revoke before HealthKitService clears durable consent.
final class SettingsDisconnectLocalFirstTests: XCTestCase {
    override func setUp() {
        HealthKitServiceTestLock.lock.lock()
        SettingsConsentRevokeURLProtocol.reset()
    }

    override func tearDown() {
        SettingsConsentRevokeURLProtocol.reset()
        HealthKitServiceTestLock.lock.unlock()
    }

    @MainActor
    override func setUp() async throws {
        let service = HealthKitService.shared
        service.prepareForUnitTests()
        UserDefaults.standard.removeObject(forKey: "hiair.health.authorizationCompleted.user-a")
        UserDefaults.standard.removeObject(forKey: "hiair.health.consentPersisted.user-a")
    }

    @MainActor
    override func tearDown() async throws {
        HealthKitService.shared.prepareForUnitTests()
    }

    @MainActor
    func testSettingsDisconnectDoesNotRemoteRevokeBeforeLocalClear() async {
        let service = HealthKitService.shared
        service.seedDurableConsentMarkersForTests(userId: "user-a")
        service.bindAccount(userId: "user-a")
        service.reportConnectionState(.connected)
        XCTAssertTrue(service.hasDurableConsent(for: "user-a"))
        XCTAssertEqual(service.connectionState, .connected)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SettingsConsentRevokeURLProtocol.self]
        config.timeoutIntervalForRequest = 5
        let api = APIClient(
            baseURL: URL(string: "https://settings-revoke.test")!,
            session: URLSession(configuration: config)
        )
        let viewModel = SettingsViewModel(apiClient: api)
        viewModel.userId = "user-a"
        viewModel.accessToken = "token"

        var settingsDeletesSeenDuringServiceRemote = -1
        service.testRemoteRevokeHandler = {
            // Service remote await must run only after local clear, and Settings must not
            // have already issued DELETE /wearables/consent (the old premature path).
            XCTAssertFalse(
                service.hasDurableConsent(for: "user-a"),
                "durable consent must be cleared before any remote revoke await"
            )
            XCTAssertEqual(service.connectionState, .revoking)
            settingsDeletesSeenDuringServiceRemote = SettingsConsentRevokeURLProtocol.consentDeleteCount
            XCTAssertEqual(
                SettingsConsentRevokeURLProtocol.consentDeleteCount,
                0,
                "Settings must not call revokeWearableConsent before HealthKitService local-first revoke"
            )
        }

        await viewModel.disconnectWearables()

        XCTAssertEqual(settingsDeletesSeenDuringServiceRemote, 0)
        XCTAssertEqual(
            SettingsConsentRevokeURLProtocol.consentDeleteCount,
            0,
            "Settings disconnect must not own a separate remote revoke"
        )
        XCTAssertFalse(service.hasDurableConsent(for: "user-a"))
        XCTAssertNotEqual(service.connectionState, .connected)
    }
}
