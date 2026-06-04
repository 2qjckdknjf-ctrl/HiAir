import XCTest
@testable import HiAir

final class SubscriptionServiceTests: XCTestCase {
    func testStoreProductIdsMatchBackendCatalog() {
        XCTAssertEqual(SubscriptionService.monthlyProductId, "com.hiair.premium.monthly")
        XCTAssertEqual(SubscriptionService.yearlyProductId, "com.hiair.premium.yearly")
    }
}
