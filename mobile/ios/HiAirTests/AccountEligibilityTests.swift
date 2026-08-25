import XCTest
@testable import HiAir

final class AccountEligibilityTests: XCTestCase {
    func testThirteenAndOlderIsEligible() {
        let now = Date()
        let exactlyThirteen = Calendar.current.date(byAdding: .year, value: -13, to: now) ?? now
        XCTAssertTrue(AccountEligibility.isEligible(dateOfBirth: exactlyThirteen, now: now))
        let adult = Calendar.current.date(byAdding: .year, value: -30, to: now) ?? now
        XCTAssertTrue(AccountEligibility.isEligible(dateOfBirth: adult, now: now))
    }

    func testUnderThirteenIsNotEligible() {
        let now = Date()
        let twelve = Calendar.current.date(byAdding: .year, value: -12, to: now) ?? now
        XCTAssertFalse(AccountEligibility.isEligible(dateOfBirth: twelve, now: now))
    }
}
