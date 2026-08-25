import XCTest
@testable import HiAir

@MainActor
private final class FakeAppleSignIn: AppleSignInStarting {
    var result: Result<(AppleIDTokenPayload, String), Error> = .failure(AppleSignInError.cancelled)
    var startCount = 0

    func signIn() async throws -> (credential: AppleIDTokenPayload, rawNonce: String) {
        startCount += 1
        return try result.get()
    }
}

@MainActor
private final class FakeAppleCredentialState: AppleIDCredentialStateChecking {
    var state: AppleIDCredentialState = .authorized
    var lastUserID: String?

    func state(forUserID userID: String) async -> AppleIDCredentialState {
        lastUserID = userID
        return state
    }
}

private final class AppleAuthURLProtocol: URLProtocol, @unchecked Sendable {
    struct CapturedRequest: Sendable {
        let method: String?
        let url: URL?
        let body: Data?
    }

    nonisolated(unsafe) static var requests: [CapturedRequest] = []
    nonisolated(unsafe) static var tokenJSON: [String: Any] = [:]
    nonisolated(unsafe) static var tokenStatus = 200

    nonisolated static func reset() {
        requests = []
        tokenJSON = [
            "access_token": "access-apple",
            "refresh_token": "refresh-apple",
            "user": [
                "id": "user-apple",
                "email": "reviewer@privaterelay.appleid.com",
            ],
        ]
        tokenStatus = 200
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody
            ?? request.httpBodyStream.flatMap { stream -> Data? in
                let data = NSMutableData()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
                defer { buffer.deallocate() }
                stream.open()
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: 1024)
                    if read > 0 {
                        data.append(buffer, length: read)
                    } else {
                        break
                    }
                }
                stream.close()
                return data as Data
            }
        Self.requests.append(
            CapturedRequest(method: request.httpMethod, url: request.url, body: body)
        )
        let url = request.url ?? URL(string: "https://auth.test.hiair.invalid/auth/v1/token")!
        let payload = try! JSONSerialization.data(withJSONObject: Self.tokenJSON)
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.tokenStatus,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
final class AppleSignInAuthTests: XCTestCase {
    private let baseURL = URL(string: "https://auth.test.hiair.invalid")!
    private let appleSignIn = FakeAppleSignIn()
    private let credentialState = FakeAppleCredentialState()
    private let appleUsers = InMemoryAppleUserIdentifierStore()

    override func setUp() async throws {
        AppleAuthURLProtocol.reset()
        APIClient.setAuthState(nil)
        appleUsers.clear()
        appleSignIn.startCount = 0
        credentialState.state = .authorized
    }

    override func tearDown() async throws {
        AppleAuthURLProtocol.reset()
        APIClient.setAuthState(nil)
        appleUsers.clear()
    }

    private func makeService() -> SupabaseAuthService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AppleAuthURLProtocol.self]
        return SupabaseAuthService(
            urlSession: URLSession(configuration: config),
            supabaseURL: baseURL,
            anonKey: "test-anon-key",
            appleSignIn: appleSignIn,
            appleCredentialState: credentialState,
            appleUserIdentifiers: appleUsers
        )
    }

    func testNonceHashIsSha256Hex() {
        XCTAssertEqual(
            AppleSignInNonce.sha256Hex(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        XCTAssertEqual(AppleSignInNonce.sha256Hex("nonce").count, 64)
    }

    func testAppleSignInExchangesHashedNonceIdTokenGrant() async throws {
        let rawNonce = "raw-apple-nonce"
        appleSignIn.result = .success((
            AppleIDTokenPayload(
                userIdentifier: "apple.user.001",
                identityToken: Data("id-token-apple".utf8),
                authorizationCode: Data("auth-code".utf8),
                email: "reviewer@privaterelay.appleid.com"
            ),
            rawNonce
        ))
        let service = makeService()
        let session = try await service.signInWithApple()

        XCTAssertEqual(appleSignIn.startCount, 1)
        XCTAssertEqual(session.userId, "user-apple")
        XCTAssertEqual(session.email, "reviewer@privaterelay.appleid.com")
        XCTAssertEqual(appleUsers.current(), "apple.user.001")
        XCTAssertEqual(AppleAuthURLProtocol.requests.count, 1)
        XCTAssertEqual(AppleAuthURLProtocol.requests[0].url?.path, "/auth/v1/token")
        XCTAssertTrue(
            AppleAuthURLProtocol.requests[0].url?.query?.contains("grant_type=id_token") == true
        )
        let body = try JSONSerialization.jsonObject(
            with: AppleAuthURLProtocol.requests[0].body ?? Data()
        ) as? [String: String]
        XCTAssertEqual(body?["provider"], "apple")
        XCTAssertEqual(body?["id_token"], "id-token-apple")
        XCTAssertEqual(body?["nonce"], rawNonce)
    }

    func testAppleSignInCancellationDoesNotHitTokenEndpoint() async {
        appleSignIn.result = .failure(AppleSignInError.cancelled)
        let service = makeService()
        do {
            _ = try await service.signInWithApple()
            XCTFail("expected cancellation")
        } catch AppleSignInError.cancelled {
            XCTAssertEqual(AppleAuthURLProtocol.requests.count, 0)
            XCTAssertNil(appleUsers.current())
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testRestoreSessionRefreshesWithStoredRefreshToken() async throws {
        AppleAuthURLProtocol.tokenJSON = [
            "access_token": "access-refreshed",
            "refresh_token": "refresh-rotated",
            "user": [
                "id": "user-restored",
                "email": "restored@hiair.io",
            ],
        ]
        APIClient.setAuthState(
            APIClient.AuthState(
                userId: "user-old",
                accessToken: "access-old",
                refreshToken: "refresh-old"
            )
        )
        let service = makeService()
        let session = try await service.restoreSessionIfNeeded()

        XCTAssertEqual(session?.userId, "user-restored")
        XCTAssertEqual(session?.accessToken, "access-refreshed")
        XCTAssertEqual(AppleAuthURLProtocol.requests.count, 1)
        XCTAssertTrue(
            AppleAuthURLProtocol.requests[0].url?.query?.contains("grant_type=refresh_token") == true
        )
        let body = try JSONSerialization.jsonObject(
            with: AppleAuthURLProtocol.requests[0].body ?? Data()
        ) as? [String: String]
        XCTAssertEqual(body?["refresh_token"], "refresh-old")
    }

    func testRevokedAppleCredentialClearsSessionWithoutRefresh() async throws {
        appleUsers.save("apple.user.revoked")
        credentialState.state = .revoked
        APIClient.setAuthState(
            APIClient.AuthState(
                userId: "user-old",
                accessToken: "access-old",
                refreshToken: "refresh-old"
            )
        )
        let service = makeService()
        let session = try await service.restoreSessionIfNeeded()

        XCTAssertNil(session)
        XCTAssertNil(appleUsers.current())
        XCTAssertNil(APIClient.getAuthState())
        XCTAssertEqual(AppleAuthURLProtocol.requests.count, 0)
        XCTAssertEqual(credentialState.lastUserID, "apple.user.revoked")
    }
}
