import XCTest
@testable import HiAir

final class HiAirHumanDateTests: XCTestCase {
    func testParsesISOInternetDateTime() {
        let date = HiAirHumanDate.date(fromISO: "2024-07-19T08:00:00+00:00")
        XCTAssertNotNil(date)
    }

    func testParsesISOWithFractionalSeconds() {
        let date = HiAirHumanDate.date(fromISO: "2026-07-18T07:16:06.013733+00:00")
        XCTAssertNotNil(date)
    }

    func testDisplayNeverReturnsRawISO() {
        let iso = "2024-07-19T08:00:00+00:00"
        let displayed = HiAirHumanDate.display(
            fromISO: iso,
            locale: Locale(identifier: "en_US"),
            style: .dateTime,
            unavailable: "—"
        )
        XCTAssertFalse(displayed.contains("T08:00:00"))
        XCTAssertFalse(displayed.contains("+00:00"))
        XCTAssertNotEqual(displayed, iso)
    }

    func testInvalidISOReturnsUnavailableFallback() {
        let displayed = HiAirHumanDate.display(fromISO: "not-a-date", unavailable: "—")
        XCTAssertEqual(displayed, "—")
    }

    func testTimeRangeUsesEnDash() {
        let start = HiAirHumanDate.date(fromISO: "2024-07-19T08:00:00Z")!
        let end = HiAirHumanDate.date(fromISO: "2024-07-19T09:00:00Z")!
        let range = HiAirHumanDate.timeRange(
            from: start,
            to: end,
            locale: Locale(identifier: "en_GB"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertTrue(range.contains("–"))
        XCTAssertFalse(range.contains("T08"))
    }
}

final class HiAirStatusLevelTests: XCTestCase {
    func testMapsLegacyRiskTokens() {
        XCTAssertEqual(HiAirStatusLevel(riskLevel: "low"), .good)
        XCTAssertEqual(HiAirStatusLevel(riskLevel: "moderate"), .moderate)
        XCTAssertEqual(HiAirStatusLevel(riskLevel: "high"), .bad)
        XCTAssertEqual(HiAirStatusLevel(riskLevel: "excellent"), .excellent)
    }
}
