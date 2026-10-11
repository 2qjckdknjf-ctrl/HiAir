import XCTest
@testable import HiAir

final class ActionTimePreferenceTests: XCTestCase {
    func testMorningRollsToTomorrowAfterLocalDeadline() {
        let now = ISO8601DateFormatter().date(from: "2026-10-11T16:00:00Z")!
        let result = ActionTimePreference.morning.bounds(now: now, timezone: "Europe/Madrid")
        XCTAssertEqual(result.earliest, "2026-10-12T06:00:00+02:00")
        XCTAssertEqual(result.latest, "2026-10-12T11:59:59+02:00")
    }
    func testDSTUsesLocalClockInsteadOfElapsedHoursFromMidnight() {
        let now = ISO8601DateFormatter().date(from: "2026-10-25T00:00:00Z")!
        let result = ActionTimePreference.morning.bounds(now: now, timezone: "Europe/Madrid")
        XCTAssertEqual(result.earliest, "2026-10-25T06:00:00+01:00")
        XCTAssertEqual(result.latest, "2026-10-25T11:59:59+01:00")
    }
    func testUnknownZoneDoesNotInventDeviceTimezone() {
        XCTAssertNil(ActionTimePreference.morning.bounds(timezone: "unknown").earliest)
        XCTAssertNil(ActionTimePreference.any.bounds(timezone: "Europe/Madrid").latest)
    }
}
