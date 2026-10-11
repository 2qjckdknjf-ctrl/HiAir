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
        await fulfillment(of: [entered], timeout: 15)
        guard let heldRequest = ActionOrderingProtocol.first else {
            first.cancel()
            return // The failed expectation is already recorded; do not hold a second request.
        }
        model.selectedDurationMinutes = 60
        await model.refreshActivityPlan(profileId: "profile", userId: "test", accessToken: "test", language: "en")
        heldRequest.respond(start: "2026-10-11T08:00:00+02:00", duration: 30)
        await first.value
        XCTAssertEqual(model.activityPlan?.recommendedStart, "2026-10-11T19:00:00+02:00")
        XCTAssertEqual(model.activityPlan?.durationMinutes, 60)
        XCTAssertFalse(model.activityPlanLoading)
    }
}

private final class ActionPlaceProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var calls = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.calls += 1
        let data = """
        {"profileId":"profile","activity":"walking","intensity":"low","durationMinutes":30,"timezone":"America/New_York","forecastAvailable":true,"hourly":[],"windows":[],"recommendedStart":"2026-10-12T08:00:00-04:00","planningAccess":"basic"}
        """.data(using: .utf8)!
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class ActionPlaceTimezoneTests: XCTestCase {
    @MainActor func testPlaceWithoutTimezoneRefetchesUsingReturnedZoneAndShowsLocalAcceptance() async {
        ActionPlaceProtocol.calls = 0
        let config=URLSessionConfiguration.ephemeral
        config.protocolClasses=[ActionPlaceProtocol.self]
        let session=URLSession(configuration:config)
        defer { session.invalidateAndCancel(); ProductAnalytics.testEventSink=nil }
        let model=DailyPlannerViewModel(apiClient:APIClient(baseURL:URL(string:"https://test.invalid")!,session:session))
        model.savedPlaces=[SavedPlace(id:"place",userId:"test",name:"Reference",placeType:"other",lat:40.7,lon:-74,timezone:nil,createdAt:nil)]
        model.selectedPlaceId="place"
        model.selectedTimePreference = .morning
        await model.refreshActivityPlan(profileId:"profile",userId:"test",accessToken:"test",language:"en")
        XCTAssertEqual(ActionPlaceProtocol.calls,2)
        XCTAssertEqual(model.actionTimezone,"America/New_York")
        var acceptanceProperties: [String:String] = [:]
        ProductAnalytics.testEventSink = { name, properties in
            if name == "action_plan_accepted" { acceptanceProperties=properties }
        }
        await model.markActivityPlanned(profileId:"profile",userId:"test",accessToken:"test",language:"en")
        XCTAssertTrue(model.activityPlanMarkStatus.contains("Calendar"))
        XCTAssertFalse(model.activityPlanMarkStatus.localizedCaseInsensitiveContains("protected"))
        XCTAssertEqual(acceptanceProperties["persistence"],"local")
        XCTAssertEqual(ActionPlaceProtocol.calls,2,"Local choice must not claim remote Protected Day persistence")
    }
}
