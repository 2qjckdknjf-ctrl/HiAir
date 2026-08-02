import Foundation

/// Deterministic in-process HTTP stub for Simulator UI / unit tests.
/// Never registers unless `UITestBootstrap.isMockAPIEnabled` (or unit tests set `isEnabled`).
final class UITestMockAPIProtocol: URLProtocol, @unchecked Sendable {
    struct RouteResponse: Sendable {
        var statusCode: Int
        var body: Data
        var headers: [String: String]

        static func json(_ statusCode: Int, object: Any) -> RouteResponse {
            let data = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data("[]".utf8)
            return RouteResponse(
                statusCode: statusCode,
                body: data,
                headers: ["Content-Type": "application/json"]
            )
        }

        static func raw(_ statusCode: Int, body: Data, contentType: String) -> RouteResponse {
            RouteResponse(
                statusCode: statusCode,
                body: body,
                headers: ["Content-Type": contentType]
            )
        }
    }

    nonisolated(unsafe) static var isEnabled = false
    nonisolated(unsafe) private static var routes: [String: RouteResponse] = [:]
    nonisolated(unsafe) private static var requestLog: [URLRequest] = []
    /// Optional artificial latency for race tests (nanoseconds).
    nonisolated(unsafe) static var responseDelayNanoseconds: UInt64 = 0
    /// When set, the next matching request fails with this URLError (then cleared if oneShot).
    nonisolated(unsafe) static var failNextWithURLError: URLError.Code?
    nonisolated(unsafe) static var failURLErrorPathSubstring: String?
    /// When set, matching request fails with this Error (e.g. `APIError.invalidURL`).
    nonisolated(unsafe) static var failNextWithError: Error?
    nonisolated(unsafe) static var failErrorPathSubstring: String?
    /// When > 0, keep failing matching requests with `failNextWithError` that many times.
    nonisolated(unsafe) static var failErrorRemainingCount: Int = 0
    private static let lock = NSLock()

    static func reset(
        listProfiles: RouteResponse = .json(200, object: []),
        createProfile: RouteResponse = .json(
            200,
            object: [
                "id": "profile-uitest-1",
                "user_id": "uitest-user",
                "persona_type": "adult",
                "sensitivity_level": "medium",
                "home_lat": 41.28,
                "home_lon": 1.976,
                "date_of_birth": NSNull(),
                "age_years": NSNull(),
            ]
        )
    ) {
        lock.lock()
        defer { lock.unlock() }
        requestLog.removeAll()
        responseDelayNanoseconds = 0
        failNextWithURLError = nil
        failURLErrorPathSubstring = nil
        failNextWithError = nil
        failErrorPathSubstring = nil
        failErrorRemainingCount = 0
        routes = [
            "GET /api/profiles": listProfiles,
            "POST /api/profiles": createProfile,
            "GET /api/air/current-risk": .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "assessedAt": "2026-07-28T12:00:00Z",
                    "environmental": [
                        "lat": 41.28,
                        "lon": 1.976,
                        "temperature": 24.0,
                        "feels_like": 24.0,
                        "humidity": 50.0,
                        "aqi": 42,
                        "pm25": 8.0,
                        "pm10": 12.0,
                        "ozone": 30.0,
                        "uv": 3.0,
                        "wind_speed": 2.0,
                        "source": "sample",
                        "timestamp": "2026-07-28T12:00:00Z",
                        "timezone": "Europe/Madrid",
                    ],
                    "risk": [
                        "overallRisk": "low",
                        "heatRisk": "low",
                        "airRisk": "low",
                        "outdoorRisk": "low",
                        "indoorVentilationRisk": "low",
                        "safeWindows": [],
                        "recommendationFlags": [],
                        "reasonCodes": [],
                    ],
                    "recommendation": [
                        "headline": "UITest calm air",
                        "summary": "Mock current-risk payload for Simulator UI tests.",
                        "actions": ["Stay hydrated"],
                    ],
                    "explanation": "Mock explanation",
                    "explanationSource": "sample",
                ]
            ),
            // Default: no account consent — TF167 UI harness (OS auth ≠ connected).
            "GET /api/v1/wearables/today": .json(
                200,
                object: [
                    "consent": NSNull(),
                    "dailySummary": NSNull(),
                    "personalLoad": NSNull(),
                ]
            ),
        ]
    }

    static func setRoute(method: String, path: String, response: RouteResponse) {
        lock.lock()
        defer { lock.unlock() }
        routes["\(method.uppercased()) \(path)"] = response
    }

    static var recordedRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requestLog
    }

    static func requestCount(matching pathSubstring: String, method: String? = nil) -> Int {
        recordedRequests.filter { request in
            guard let url = request.url else { return false }
            let methodOK = method == nil || request.httpMethod?.uppercased() == method?.uppercased()
            return methodOK && url.path.contains(pathSubstring)
        }.count
    }

    override class func canInit(with request: URLRequest) -> Bool {
        isEnabled
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.requestLog.append(request)
        let method = (request.httpMethod ?? "GET").uppercased()
        let path = request.url?.path ?? ""
        let key = "\(method) \(path)"
        let failCode = Self.failNextWithURLError
        let failPath = Self.failURLErrorPathSubstring
        let shouldFailURL = failCode != nil && (failPath == nil || path.contains(failPath!))
        if shouldFailURL {
            Self.failNextWithURLError = nil
            Self.failURLErrorPathSubstring = nil
        }
        let failError = Self.failNextWithError
        let failErrorPath = Self.failErrorPathSubstring
        let shouldFailError = failError != nil
            && Self.failErrorRemainingCount > 0
            && (failErrorPath == nil || path.contains(failErrorPath!))
        if shouldFailError {
            Self.failErrorRemainingCount -= 1
            if Self.failErrorRemainingCount <= 0 {
                Self.failNextWithError = nil
                Self.failErrorPathSubstring = nil
            }
        }
        let response = Self.routes[key] ?? RouteResponse.json(404, object: ["detail": "unmocked \(key)"])
        let delay = Self.responseDelayNanoseconds
        Self.lock.unlock()

        if shouldFailURL, let failCode {
            client?.urlProtocol(self, didFailWithError: URLError(failCode))
            return
        }
        if shouldFailError, let failError {
            client?.urlProtocol(self, didFailWithError: failError)
            return
        }

        let url = request.url ?? URL(string: "https://uitest.invalid")!
        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            let http = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            self.client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: response.body)
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if delay == 0 {
            finish()
            return
        }
        Task {
            try? await Task.sleep(nanoseconds: delay)
            finish()
        }
    }

    override func stopLoading() {}
}
