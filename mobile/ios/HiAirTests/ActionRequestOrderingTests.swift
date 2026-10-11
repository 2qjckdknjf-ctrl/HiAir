import XCTest
@testable import HiAir

private final class ActionOrderingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var first: ActionOrderingProtocol?
    nonisolated(unsafe) static var entered: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if Self.first == nil {
            Self.first = self
            Self.entered?()
        } else { respond(start: "2026-10-11T19:00:00+02:00", duration: 60) }
    }
    override func stopLoading() {}
    func respond(start: String, duration: Int) {
        let data = """
        {"profileId":"profile","activity":"walking","intensity":"low","durationMinutes":\(duration),"timezone":"Europe/Madrid","forecastAvailable":true,"hourly":[],"windows":[],"recommendedStart":"\(start)","planningAccess":"basic"}
        """.data(using: .utf8)!
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class ActionRequestOrderingTests: XCTestCase {
    @MainActor func testLateResponseDoesNotOverwriteNewParameters() async {
        let entered = expectation(description: "first request held")
        ActionOrderingProtocol.first = nil
        ActionOrderingProtocol.entered = { entered.fulfill() }
        defer { ActionOrderingProtocol.first = nil; ActionOrderingProtocol.entered = nil }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ActionOrderingProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let model = DailyPlannerViewModel(apiClient: APIClient(baseURL: URL(string: "https://test.invalid")!, session: session))
        let first = Task { await model.refreshActivityPlan(profileId: "profile", userId: "test", accessToken: "test", language: "en") }
        await fulfillment(of: [entered], timeout: 3)
        model.selectedDurationMinutes = 60
        await model.refreshActivityPlan(profileId: "profile", userId: "test", accessToken: "test", language: "en")
        ActionOrderingProtocol.first?.respond(start: "2026-10-11T08:00:00+02:00", duration: 30)
        await first.value
        XCTAssertEqual(model.activityPlan?.recommendedStart, "2026-10-11T19:00:00+02:00")
        XCTAssertEqual(model.activityPlan?.durationMinutes, 60)
        XCTAssertFalse(model.activityPlanLoading)
    }
}
