import Combine
import XCTest
@testable import HiAir

private final class InsightsLoadingProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((InsightsLoadingProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() {}
    func respond(_ body: String, status: Int = 200) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class InsightsLoadingTests: XCTestCase {
    @MainActor func testPrimaryCardsDoNotWaitForStalledHistory() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InsightsLoadingProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); InsightsLoadingProtocol.handler = nil }
        let model = InsightsViewModel(apiClient: APIClient(baseURL: URL(string:"https://test.invalid")!, session: session),
            deadlineNanoseconds: 5_000_000_000)
        model.loggedDays = 7
        let rendered = expectation(description: "Primary cards rendered before history timeout")
        let cancellable = model.$loading
            .filter { !$0 && !model.todaySummary.isEmpty }
            .prefix(1)
            .sink { _ in rendered.fulfill() }
        defer { cancellable.cancel() }
        InsightsLoadingProtocol.handler = { request in
            if request.request.url!.path == "/api/symptoms/history" { return }
            if request.request.url!.path == "/api/v1/health/insights" {
                request.respond("""
                {"profileId":"profile","generatedAt":"2026-10-11T12:00:00Z","today":{},"trends":[],"associations":[],"insufficientData":[]}
                """)
            } else { request.respond("{}",status:503) }
        }
        let task = Task { await model.refresh(profileId:"profile", userId:"owned-user", accessToken:"test", language:"en") }
        await fulfillment(of:[rendered],timeout:4)
        XCTAssertFalse(model.loading)
        XCTAssertFalse(model.todaySummary.isEmpty)
        await task.value
        XCTAssertTrue(model.partialFailure)
        XCTAssertFalse(model.loading)
    }

    @MainActor func testTransportFailureShowsRetryRatherThanNoData() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InsightsLoadingProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); InsightsLoadingProtocol.handler = nil }
        InsightsLoadingProtocol.handler = { $0.respond("{}",status:503) }
        let model = InsightsViewModel(apiClient: APIClient(baseURL:URL(string:"https://test.invalid")!,session:session))
        await model.refresh(profileId:"profile",userId:"owned-user",accessToken:"test",language:"en")
        XCTAssertNotNil(model.lastError)
        XCTAssertTrue(model.partialFailure)
        XCTAssertFalse(model.loading)
    }
}

private final class PerformanceCredentials: SessionCredentialStoring {
    private var values: [String:String] = [:]
    func getString(forKey key: String) -> String? { values[key] }
    func setString(_ value: String, forKey key: String) { values[key] = value }
    func deleteValue(forKey key: String) { values.removeValue(forKey:key) }
}

final class EntitlementRefreshPerformanceTests: XCTestCase {
    @MainActor func testDuplicateRefreshesShareRequestAndCannotUndoConfirmedPurchase() async {
        let config=URLSessionConfiguration.ephemeral
        config.protocolClasses=[InsightsLoadingProtocol.self]
        let session=URLSession(configuration:config)
        let defaults=UserDefaults(suiteName:"entitlement-perf-"+UUID().uuidString)!
        let model=AppSession(defaults:defaults,credentials:PerformanceCredentials(),
            apiClient:APIClient(baseURL:URL(string:"https://test.invalid")!,session:session))
        model.userId="owned-user"; model.accessToken="test"
        defer { model.cancelLifecycleForTests(); session.invalidateAndCancel(); InsightsLoadingProtocol.handler=nil }
        let entered=expectation(description:"Entitlement request held")
        var held: InsightsLoadingProtocol?
        var count=0
        let lock=NSLock()
        InsightsLoadingProtocol.handler = { request in
            lock.lock(); count += 1; held=request; lock.unlock(); entered.fulfill()
        }
        let first=Task { await model.refreshEntitlement() }
        let second=Task { await model.refreshEntitlement() }
        await fulfillment(of:[entered],timeout:15)
        await Task.yield()
        model.applyEntitlement(UserEntitlementResponse(userId:"owned-user",plan:"premium",isPremium:true,
            maxProfiles:6,extendedForecastEnabled:true,customAlertsEnabled:true,
            exportReportsEnabled:true,advancedInsightsEnabled:true))
        lock.lock(); let response=held; lock.unlock()
        response?.respond("{\"user_id\":\"owned-user\",\"status\":\"inactive\",\"auto_renew\":false,\"entitlement\":null}")
        await first.value; await second.value
        XCTAssertEqual(count,1)
        XCTAssertTrue(model.isPremium,"Old /me must not undo a confirmed purchase")
    }
}
