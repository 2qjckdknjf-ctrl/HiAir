import XCTest
@testable import HiAir

final class HourlyRiskChartHonestyTests: XCTestCase {
    func testUnknownRiskIsGapNotLow() {
        XCTAssertEqual(HiAirHourlyRiskChart.score(for: "low"), 20)
        XCTAssertEqual(HiAirHourlyRiskChart.score(for: "moderate"), 45)
        XCTAssertEqual(HiAirHourlyRiskChart.score(for: "high"), 70)
        XCTAssertEqual(HiAirHourlyRiskChart.score(for: "very_high"), 90)
        XCTAssertNil(HiAirHourlyRiskChart.score(for: "unknown"))
        XCTAssertNil(HiAirHourlyRiskChart.score(for: ""))
        XCTAssertNil(HiAirHourlyRiskChart.score(for: "missing"))
    }

    func testHourParsingUsesPlaceTimeZone() {
        // 2026-08-08T14:00:00Z is 16:00 in Europe/Madrid (CEST, UTC+2).
        let hour = HiAirDeepGlassTime.hour(
            from: "2026-08-08T14:00:00Z",
            timeZoneIdentifier: "Europe/Madrid"
        )
        XCTAssertEqual(hour, 16)
    }
}
