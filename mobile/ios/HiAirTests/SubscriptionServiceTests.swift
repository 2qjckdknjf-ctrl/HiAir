import XCTest
@testable import HiAir

final class SubscriptionServiceTests: XCTestCase {
    func testStoreProductIdsMatchBackendCatalog() {
        XCTAssertEqual(SubscriptionService.monthlyProductId, "com.hiair.premium.monthly")
        XCTAssertEqual(SubscriptionService.yearlyProductId, "com.hiair.premium.yearly")
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
}

final class PurchaseSingleFlightGuardTests: XCTestCase {
    func testBeginSetsActiveUntilEnd() {
        var guardState = PurchaseSingleFlightGuard()
        XCTAssertFalse(guardState.isActive)
        XCTAssertTrue(guardState.begin())
        XCTAssertTrue(guardState.isActive)
        guardState.end()
        XCTAssertFalse(guardState.isActive)
    }
}
