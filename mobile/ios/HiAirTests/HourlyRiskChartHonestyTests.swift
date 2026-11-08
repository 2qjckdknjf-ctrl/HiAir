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

    func testAbsoluteTimestampScalePlacesOvernightWindowNearStart() {
        // Series 14:00 today → 13:00 tomorrow. Window 16:00–18:00 must sit near the start,
        // not around hour/24 of the next calendar day (~05:20–07:15).
        let points = (0..<24).map { offset -> AirHourlyRiskPoint in
            let hour = 14 + offset
            let day = hour >= 24 ? "09" : "08"
            let localHour = hour % 24
            return AirHourlyRiskPoint(
                hour: String(format: "2026-08-%@T%02d:00:00+02:00", day, localHour),
                overallRisk: offset == 5 ? "unknown" : "moderate"
            )
        }
        let scale = HiAirChartTimeScale.domain(from: points)
        XCTAssertNotNil(scale)
        guard let scale else { return }

        let width: CGFloat = 240
        let start = HiAirHumanDate.date(fromISO: "2026-08-08T16:00:00+02:00")!
        let end = HiAirHumanDate.date(fromISO: "2026-08-08T18:00:00+02:00")!
        let x0 = scale.x(for: start, width: width)
        let x1 = scale.x(for: end, width: width)
        XCTAssertNotNil(x0)
        XCTAssertNotNil(x1)
        guard let x0, let x1 else { return }

        // 16:00 is 2h after domain start 14:00 → 2/23 of the width (~20.9).
        XCTAssertEqual(x0, width * (2.0 / 23.0), accuracy: 0.5)
        XCTAssertEqual(x1, width * (4.0 / 23.0), accuracy: 0.5)
        XCTAssertLessThan(x0, width * 0.15)
        XCTAssertLessThan(x1, width * 0.25)

        // Unknown hour is a gap in scoring, but the domain still uses its timestamp for X.
        XCTAssertNil(HiAirHourlyRiskChart.score(for: points[5].overallRisk))
        XCTAssertNotNil(scale.x(forISO: points[5].hour, width: width))

        // “Now” outside the forecast domain must not map.
        let before = HiAirHumanDate.date(fromISO: "2026-08-08T10:00:00+02:00")!
        XCTAssertNil(scale.fraction(for: before))
    }

    func testDomainRequiresDistinctTimestamps() {
        let same = [
            AirHourlyRiskPoint(hour: "2026-08-08T14:00:00Z", overallRisk: "low"),
            AirHourlyRiskPoint(hour: "2026-08-08T14:00:00Z", overallRisk: "high"),
        ]
        XCTAssertNil(HiAirChartTimeScale.domain(from: same))
    }
}
