import XCTest
@testable import HiAir

@MainActor
private final class FakeOAuthWebSession: OAuthWebSessionStarting {
    var lastURL: URL?
    var lastScheme: String?
    var result: Result<URL, Error> = .failure(OAuthSignInError.cancelled)
    var startCount = 0

    func start(url: URL, callbackScheme: String) async throws -> URL {
        startCount += 1
        lastURL = url
        lastScheme = callbackScheme
        return try result.get()
    }
}

private final class GoogleOAuthURLProtocol: URLProtocol, @unchecked Sendable {
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
            "access_token": "access-google",
            "refresh_token": "refresh-google",
            "user": [
                "id": "user-google",
                "email": "reviewer@hiair.io",
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
final class GoogleOAuthWebSessionTests: XCTestCase {
    private let baseURL = URL(string: "https://auth.test.hiair.invalid")!
    private let fake = FakeOAuthWebSession()

    override func setUp() async throws {
        GoogleOAuthURLProtocol.reset()
        APIClient.setAuthState(nil)
    }

    override func tearDown() async throws {
        GoogleOAuthURLProtocol.reset()
        APIClient.setAuthState(nil)
    }

    private func makeService() -> SupabaseAuthService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GoogleOAuthURLProtocol.self]
        return SupabaseAuthService(
            urlSession: URLSession(configuration: config),
            supabaseURL: baseURL,
            anonKey: "test-anon-key",
            oauthWebSession: fake
        )
    }

    func testGoogleSignInUsesInAppCallbackSchemeAndAuthorizeURL() async throws {
        fake.result = .success(URL(string: "hiair://auth/callback?code=pkce-code")!)
        let service = makeService()
        let session = try await service.signInWithGoogle()

        XCTAssertEqual(fake.startCount, 1)
        XCTAssertEqual(fake.lastScheme, "hiair")
        let url = try XCTUnwrap(fake.lastURL)
        XCTAssertEqual(url.host, baseURL.host)
        XCTAssertEqual(url.path, "/auth/v1/authorize")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        XCTAssertEqual(query["provider"], "google")
        XCTAssertEqual(query["redirect_to"], "hiair://auth/callback")
        XCTAssertEqual(query["code_challenge_method"], "s256")
        XCTAssertFalse(query["code_challenge"]?.isEmpty ?? true)

        XCTAssertEqual(session.userId, "user-google")
        XCTAssertEqual(session.email, "reviewer@hiair.io")
        XCTAssertEqual(GoogleOAuthURLProtocol.requests.count, 1)
        XCTAssertEqual(GoogleOAuthURLProtocol.requests[0].url?.path, "/auth/v1/token")
        let body = try JSONSerialization.jsonObject(
            with: GoogleOAuthURLProtocol.requests[0].body ?? Data()
        ) as? [String: String]
        XCTAssertEqual(body?["auth_code"], "pkce-code")
        XCTAssertFalse(body?["code_verifier"]?.isEmpty ?? true)
    }

    func testGoogleSignInCancellationDoesNotExchangeCode() async {
        fake.result = .failure(OAuthSignInError.cancelled)
        let service = makeService()
        do {
            _ = try await service.signInWithGoogle()
            XCTFail("expected cancellation")
        } catch OAuthSignInError.cancelled {
            XCTAssertEqual(GoogleOAuthURLProtocol.requests.count, 0)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testDuplicateCallbackAfterSuccessDoesNotFail() async throws {
        fake.result = .success(URL(string: "hiair://auth/callback?code=pkce-code")!)
        let service = makeService()
        _ = try await service.signInWithGoogle()
        let duplicate = await service.handleCallbackURL(
            URL(string: "hiair://auth/callback?code=pkce-code")!
        )
        XCTAssertTrue(duplicate)
        XCTAssertEqual(GoogleOAuthURLProtocol.requests.count, 1)
    }
}
