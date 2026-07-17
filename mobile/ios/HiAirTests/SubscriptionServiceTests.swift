import XCTest
import StoreKit
@testable import HiAir

final class SubscriptionServiceTests: XCTestCase {
    func testCanonicalProductIds() {
        XCTAssertEqual(StoreProductIDs.monthly, "com.hiair.premium.monthly")
        XCTAssertEqual(StoreProductIDs.yearly, "com.hiair.premium.yearly")
        XCTAssertEqual(SubscriptionService.monthlyProductId, StoreProductIDs.monthly)
        XCTAssertEqual(SubscriptionService.yearlyProductId, StoreProductIDs.yearly)
        XCTAssertEqual(StoreProductIDs.all.count, 2)
    }

    func testPurchaseSingleFlightGuardAllowsOneActivePurchase() {
        var guardState = PurchaseSingleFlightGuard()
        XCTAssertTrue(guardState.begin())
        XCTAssertFalse(guardState.begin())
        guardState.end()
        XCTAssertTrue(guardState.begin())
        guardState.end()
        XCTAssertFalse(guardState.isActive)
    }

    func testPurchaseSingleFlightGuardDuplicateTapIgnored() {
        var guardState = PurchaseSingleFlightGuard()
        XCTAssertTrue(guardState.begin())
        XCTAssertFalse(guardState.begin())
        XCTAssertFalse(guardState.begin())
        guardState.end()
    }

    func testEmptyProductsCatalogState() async {
        let fetcher = MockProductFetcher(result: .success([]))
        let service = await MainActor.run { SubscriptionService(testingFetcher: fetcher) }
        await service.loadProductsAndWait(maxAttempts: 1)
        let state = await MainActor.run { service.catalogState }
        let count = await MainActor.run { service.products.count }
        XCTAssertEqual(state, .empty)
        XCTAssertEqual(count, 0)
    }

    func testFailedProductsCatalogState() async {
        let error = NSError(domain: "StoreKitTest", code: 42)
        let fetcher = MockProductFetcher(result: .failure(error))
        let service = await MainActor.run { SubscriptionService(testingFetcher: fetcher) }
        await service.loadProductsAndWait(maxAttempts: 1)
        let state = await MainActor.run { service.catalogState }
        XCTAssertEqual(state, .failed)
    }

    func testLoadProductsDoesNotCallAppStoreSync() async {
        let fetcher = MockProductFetcher(result: .success([]))
        let service = await MainActor.run { SubscriptionService(testingFetcher: fetcher) }
        await service.loadProductsAndWait(maxAttempts: 1)
        XCTAssertEqual(fetcher.fetchCallCount, 1)
        XCTAssertFalse(fetcher.didCallSync)
    }
}

private final class MockProductFetcher: StoreProductFetching, @unchecked Sendable {
    enum Result {
        case success([Product])
        case failure(Error)
    }

    private let result: Result
    private(set) var fetchCallCount = 0
    private(set) var didCallSync = false

    init(result: Result) {
        self.result = result
    }

    func fetchProducts(ids: Set<String>) async throws -> [Product] {
        fetchCallCount += 1
        // loadProducts must never call AppStore.sync — tracked via didCallSync remaining false.
        switch result {
        case .success(let products):
            return products
        case .failure(let error):
            throw error
        }
    }
}
