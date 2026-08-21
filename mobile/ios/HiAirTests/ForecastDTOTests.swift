import XCTest
@testable import HiAir

final class ForecastDTOTests: XCTestCase {
    func testDayPlanDecodesAdditiveMetadataAndOptionalMetrics() throws {
        let json = """
        {
          "profileId": "profile-1",
          "timezone": "Europe/Madrid",
          "hourlyRisk": [{"hour": "2026-07-15T08:00:00+02:00", "overallRisk": "low"}],
          "safeWindows": [{"type": "walk", "start": "2026-07-15T08:00:00+02:00", "end": "2026-07-15T10:00:00+02:00", "confidence": 0.86}],
          "ventilationWindows": [],
          "generatedAt": "2026-07-15T08:05:00+02:00",
          "dataQuality": "partial",
          "freshness": "cached",
          "sources": ["openmeteo_weather"],
          "forecastHours": 24,
          "forecastAvailable": true,
          "missingMetrics": ["pm10_ugm3"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AirDayPlanResponse.self, from: json)
        XCTAssertEqual(decoded.timezone, "Europe/Madrid")
        XCTAssertEqual(decoded.dataQuality, "partial")
        XCTAssertEqual(decoded.freshness, "cached")
        XCTAssertEqual(decoded.forecastHours, 24)
        XCTAssertTrue(decoded.isForecastAvailable)
        XCTAssertEqual(decoded.missingMetrics, ["pm10_ugm3"])
    }

    func testDayPlanUnavailableWhenHourlyEmpty() throws {
        let json = """
        {
          "profileId": "profile-1",
          "timezone": "UTC",
          "hourlyRisk": [],
          "safeWindows": [],
          "ventilationWindows": [],
          "forecastAvailable": false
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AirDayPlanResponse.self, from: json)
        XCTAssertFalse(decoded.isForecastAvailable)
    }

    func testEnvironmentalInputDecodesNullOptionalMetrics() throws {
        let json = """
        {
          "lat": 41.39,
          "lon": 2.17,
          "temperature": 24.0,
          "feels_like": 25.0,
          "humidity": null,
          "aqi": 40,
          "pm25": 8.0,
          "pm10": null,
          "ozone": 30.0,
          "uv": null,
          "wind_speed": null,
          "source": "live",
          "timestamp": "2026-07-15T08:00:00+02:00",
          "timezone": "Europe/Madrid"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AirEnvironmentalInput.self, from: json)
        XCTAssertNil(decoded.humidity)
        XCTAssertNil(decoded.pm10)
        XCTAssertNil(decoded.uv)
        XCTAssertNil(decoded.windSpeed)
        XCTAssertEqual(decoded.aqi, 40)
    }

    func testWindowFormattingUsesForecastTimezoneNotDevice() {
        let start = "2026-07-15T08:00:00+02:00"
        let end = "2026-07-15T09:00:00+02:00"
        let madrid = TimeZone(identifier: "Europe/Madrid")!
        let range = HiAirHumanDate.timeRange(
            fromISO: start,
            toISO: end,
            locale: Locale(identifier: "en_GB"),
            timeZone: madrid,
            unavailable: "—"
        )
        XCTAssertTrue(range.contains("08") || range.contains("8"))
        XCTAssertFalse(range.contains("T08"))
    }

    func testActivityPlanDecodesWindowsAndMetadata() throws {
        let json = """
        {
          "profileId": "profile-1",
          "activity": "running",
          "intensity": "high",
          "durationMinutes": 45,
          "timezone": "Europe/Madrid",
          "forecastAvailable": true,
          "dataQuality": "complete",
          "freshness": "live",
          "sources": ["openmeteo_weather"],
          "missingMetrics": [],
          "generatedAt": "2026-08-21T07:05:00+02:00",
          "hourly": [{"hour": "2026-08-21T07:00:00+02:00", "tier": "best", "score": 90, "reasonCodes": ["good_air"]}],
          "windows": [{"tier": "best", "start": "2026-08-21T07:00:00+02:00", "end": "2026-08-21T08:00:00+02:00", "score": 90, "reasonCodes": ["good_air"], "confidence": 0.92}],
          "recommendedStart": "2026-08-21T07:00:00+02:00",
          "personalLoadScore": 35,
          "personalLoadLevel": "moderate",
          "personalLoadReasonCodes": ["sleep_debt"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ActivityPlanResponse.self, from: json)
        XCTAssertEqual(decoded.activity, "running")
        XCTAssertTrue(decoded.isForecastAvailable)
        XCTAssertEqual(decoded.windows.count, 1)
        XCTAssertEqual(decoded.windows[0].tier, "best")
        XCTAssertEqual(decoded.recommendedStart, "2026-08-21T07:00:00+02:00")
        XCTAssertEqual(decoded.personalLoadScore, 35)
    }

    func testActivityCatalogDecodes() throws {
        let json = """
        {
          "activities": [
            {"activity": "walking", "defaultDurationMinutes": 30, "defaultIntensity": "low", "outdoor": true},
            {"activity": "ventilation", "defaultDurationMinutes": 60, "defaultIntensity": "low", "outdoor": false}
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ActivityCatalogResponse.self, from: json)
        XCTAssertEqual(decoded.activities.count, 2)
        XCTAssertFalse(decoded.activities[1].outdoor)
    }
}
