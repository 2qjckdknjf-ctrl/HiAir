import XCTest
@testable import HiAir

/// Deterministic `URLProtocol` capture for production `SupabaseAuthService` HTTP shape.
private final class AuthLogoutURLProtocol: URLProtocol, @unchecked Sendable {
    struct CapturedRequest: Sendable {
        let method: String?
        let url: URL?
        let authorization: String?
        let apiKey: String?
        let contentType: String?
        let body: Data?
    }

    nonisolated(unsafe) static var requests: [CapturedRequest] = []
    nonisolated(unsafe) static var statusCode: Int = 204
    nonisolated(unsafe) static var failWithError: Error?

    nonisolated static func reset(statusCode: Int = 204, failWithError: Error? = nil) {
        requests = []
        self.statusCode = statusCode
        self.failWithError = failWithError
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
            CapturedRequest(
                method: request.httpMethod,
                url: request.url,
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                apiKey: request.value(forHTTPHeaderField: "apikey"),
                contentType: request.value(forHTTPHeaderField: "Content-Type"),
                body: body
            )
        )
        if let failWithError = Self.failWithError {
            client?.urlProtocol(self, didFailWithError: failWithError)
            return
        }
        let url = request.url ?? URL(string: "https://example.invalid/auth/v1/logout")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class SupabaseAuthLogoutTransportTests: XCTestCase {
    private let baseURL = URL(string: "https://auth.test.hiair.invalid")!
    private let anonKey = "test-anon-key"

    @MainActor
    private func makeService() -> SupabaseAuthService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthLogoutURLProtocol.self]
        let session = URLSession(configuration: config)
        return SupabaseAuthService(
            urlSession: session,
            supabaseURL: baseURL,
            anonKey: anonKey
        )
    }

    override func setUp() {
        super.setUp()
        AuthLogoutURLProtocol.reset()
    }

    override func tearDown() {
        AuthLogoutURLProtocol.reset()
        APIClient.setAuthState(nil)
        super.tearDown()
    }

    @MainActor
    func testRevokeRemoteSessionPostsExactLogoutContract() async {
        let service = makeService()
        await service.revokeRemoteSession(accessToken: "captured-original-token")

        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 1)
        let req = AuthLogoutURLProtocol.requests[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url?.path, "/auth/v1/logout")
        XCTAssertEqual(req.url?.host, baseURL.host)
        XCTAssertEqual(req.authorization, "Bearer captured-original-token")
        XCTAssertEqual(req.apiKey, anonKey)
        XCTAssertEqual(req.contentType, "application/json")
        let body = try! JSONSerialization.jsonObject(with: req.body ?? Data()) as? [String: Any]
        XCTAssertEqual(body?.count, 0)
    }

    @MainActor
    func testRevokeRemoteSessionBlankTokenMakesZeroRequests() async {
        let service = makeService()
        await service.revokeRemoteSession(accessToken: "   ")
        await service.revokeRemoteSession(accessToken: "")
        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 0)
    }

    @MainActor
    func testRevokeRemoteSessionHTTPFailureDoesNotPostNilSessionOrRestoreAuth() async {
        AuthLogoutURLProtocol.reset(statusCode: 503)
        let service = makeService()
        APIClient.setAuthState(
            APIClient.AuthState(userId: "user-b", accessToken: "bearer-b", refreshToken: "refresh-b")
        )

        var nilPosts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: nil
        ) { note in
            if note.object == nil { nilPosts += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await service.revokeRemoteSession(accessToken: "captured-a")

        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 1)
        XCTAssertEqual(AuthLogoutURLProtocol.requests[0].authorization, "Bearer captured-a")
        XCTAssertEqual(nilPosts, 0)
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
        XCTAssertEqual(APIClient.getAuthState()?.userId, "user-b")
    }

    @MainActor
    func testRevokeRemoteSessionNetworkFailureDoesNotPostNilOrRestoreAuth() async {
        AuthLogoutURLProtocol.reset(failWithError: URLError(.notConnectedToInternet))
        let service = makeService()
        APIClient.setAuthState(
            APIClient.AuthState(userId: "user-b", accessToken: "bearer-b", refreshToken: "refresh-b")
        )

        var nilPosts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: nil
        ) { note in
            if note.object == nil { nilPosts += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await service.revokeRemoteSession(accessToken: "captured-a")

        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 1)
        XCTAssertEqual(nilPosts, 0)
        XCTAssertEqual(APIClient.getAuthState()?.accessToken, "bearer-b")
    }

    @MainActor
    func testStandaloneSignOutClearsGlobalThenRevokesCapturedBearerWithoutNilBroadcast() async {
        let service = makeService()
        APIClient.setAuthState(
            APIClient.AuthState(userId: "user-a", accessToken: "bearer-a", refreshToken: "refresh-a")
        )

        var nilPosts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: nil
        ) { note in
            if note.object == nil { nilPosts += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await service.signOut()

        XCTAssertNil(APIClient.getAuthState())
        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 1)
        XCTAssertEqual(AuthLogoutURLProtocol.requests[0].method, "POST")
        XCTAssertEqual(AuthLogoutURLProtocol.requests[0].url?.path, "/auth/v1/logout")
        XCTAssertEqual(AuthLogoutURLProtocol.requests[0].authorization, "Bearer bearer-a")
        XCTAssertEqual(AuthLogoutURLProtocol.requests[0].apiKey, anonKey)
        XCTAssertEqual(nilPosts, 0)
    }

    @MainActor
    func testStandaloneSignOutWithNoGlobalAuthMakesZeroRequestsAndNoNilBroadcast() async {
        let service = makeService()
        APIClient.setAuthState(nil)

        var nilPosts = 0
        let observer = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: nil
        ) { note in
            if note.object == nil { nilPosts += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await service.signOut()

        XCTAssertEqual(AuthLogoutURLProtocol.requests.count, 0)
        XCTAssertEqual(nilPosts, 0)
        XCTAssertNil(APIClient.getAuthState())
    }
}
