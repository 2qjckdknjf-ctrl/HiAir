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
        XCTAssertNil(decoded.no2)
        XCTAssertEqual(decoded.aqi, 40)
    }

    func testEnvironmentalInputDecodesNo2WhenPresent() throws {
        let json = """
        {
          "lat": 41.39,
          "lon": 2.17,
          "temperature": 24.0,
          "feels_like": 25.0,
          "humidity": 50.0,
          "aqi": 40,
          "pm25": 8.0,
          "pm10": 12.0,
          "ozone": 30.0,
          "no2": 42.5,
          "uv": 4.0,
          "wind_speed": 2.0,
          "source": "live",
          "timestamp": "2026-07-15T08:00:00+02:00",
          "timezone": "Europe/Madrid"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AirEnvironmentalInput.self, from: json)
        XCTAssertEqual(decoded.no2, 42.5)
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

    func testHazardsResponseDecodesAssessmentFields() throws {
        let json = """
        {
          "profileId": "profile-1",
          "assessedAt": "2026-08-21T10:00:00+02:00",
          "environmental": {
            "lat": 41.39,
            "lon": 2.17,
            "temperature": 28.0,
            "feels_like": 30.0,
            "humidity": 55.0,
            "aqi": 42,
            "pm25": 9.0,
            "pm10": null,
            "ozone": 35.0,
            "uv": null,
            "wind_speed": 12.0,
            "source": "live",
            "timestamp": "2026-08-21T10:00:00+02:00",
            "timezone": "Europe/Madrid"
          },
          "assessment": {
            "profileId": "profile-1",
            "assessedAt": "2026-08-21T10:00:00+02:00",
            "hazards": [
              {"hazard": "heat", "level": "high", "score": 72, "available": true, "reasonCodes": ["heat_index"], "unavailableReason": null},
              {"hazard": "uv", "level": "unavailable", "score": 0, "available": false, "reasonCodes": [], "unavailableReason": "missing_uv"}
            ],
            "overallLevel": "moderate",
            "overallScore": 55,
            "availableCount": 1,
            "reasonCodes": ["partial_data"]
          },
          "dataQuality": "partial",
          "freshness": "live",
          "sources": ["openmeteo_weather"],
          "generatedAt": "2026-08-21T10:05:00+02:00"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HazardsResponse.self, from: json)
        XCTAssertEqual(decoded.assessment.overallLevel, "moderate")
        XCTAssertEqual(decoded.assessment.hazards.count, 2)
        XCTAssertTrue(decoded.assessment.hazards[0].available)
        XCTAssertFalse(decoded.assessment.hazards[1].available)
        XCTAssertEqual(decoded.assessment.hazards[1].unavailableReason, "missing_uv")
    }

    func testSavedPlacesListDecodes() throws {
        let json = """
        {
          "places": [
            {
              "id": "place-1",
              "userId": "user-1",
              "name": "Home",
              "placeType": "home",
              "lat": 41.39,
              "lon": 2.17,
              "timezone": "Europe/Madrid",
              "createdAt": "2026-08-21T10:00:00+00:00"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SavedPlaceListResponse.self, from: json)
        XCTAssertEqual(decoded.places.count, 1)
        XCTAssertEqual(decoded.places[0].placeType, "home")
    }

    func testTravelSessionDecodes() throws {
        let activeJson = """
        {
          "active": true,
          "placeId": "place-1",
          "placeName": "Office",
          "lat": 40.42,
          "lon": -3.70,
          "timezone": "Europe/Madrid",
          "until": null,
          "source": "travel"
        }
        """.data(using: .utf8)!
        let active = try JSONDecoder().decode(TravelSession.self, from: activeJson)
        XCTAssertTrue(active.active)
        XCTAssertEqual(active.placeId, "place-1")
        XCTAssertEqual(active.source, "travel")

        let inactiveJson = """
        {
          "active": false,
          "placeId": null,
          "placeName": null,
          "lat": null,
          "lon": null,
          "timezone": null,
          "until": null,
          "source": "home"
        }
        """.data(using: .utf8)!
        let inactive = try JSONDecoder().decode(TravelSession.self, from: inactiveJson)
        XCTAssertFalse(inactive.active)
        XCTAssertEqual(inactive.source, "home")
    }

    func testPersonalAdaptationSnapshotDecodes() throws {
        let json = """
        {
          "profileId": "profile-1",
          "generatedAt": "2026-08-21T12:00:00+00:00",
          "baselines": [
            {
              "metric": "resting_heart_rate",
              "window": "d7",
              "value": 62.0,
              "sampleSize": 5,
              "confidence": 0.8,
              "available": true
            }
          ],
          "protectedDays": {
            "highRiskPeriodsAvoided": 2,
            "workoutsMoved": 1,
            "ventilationWindowsUsed": 3,
            "poorAirExposureReduced": 1,
            "available": true
          },
          "reasonCodes": ["association_not_causation"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PersonalAdaptationSnapshot.self, from: json)
        XCTAssertEqual(decoded.baselines.count, 1)
        XCTAssertTrue(decoded.baselines[0].available)
        XCTAssertTrue(decoded.protectedDays.available)
        XCTAssertEqual(decoded.protectedDays.workoutsMoved, 1)
    }

    func testProtectedDayEventRecordDecodes() throws {
        let json = """
        {
          "id": "evt-1",
          "profileId": "profile-1",
          "eventType": "workout_moved",
          "eventDate": "2026-08-22"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ProtectedDayEventRecord.self, from: json)
        XCTAssertEqual(decoded.eventType, "workout_moved")
        XCTAssertEqual(decoded.profileId, "profile-1")
    }

    func testSiteRiskResponseDecodes() throws {
        let json = """
        {
          "assessedAt": "2026-08-22T08:00:00Z",
          "environmentalSource": "live",
          "assessment": {
            "siteId": "41.3900:2.1700",
            "wbgtC": null,
            "heatIndexC": 33.0,
            "workload": "moderate",
            "riskLevel": "high",
            "workRest": {"workMinutes": 30, "restMinutes": 30, "rationaleCodes": ["heat_index_proxy_only"]},
            "availableMetrics": ["heat_index"],
            "missingMetrics": ["wbgt"],
            "reasonCodes": ["wbgt_unavailable", "heat_index_proxy_only"]
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SiteRiskResponse.self, from: json)
        XCTAssertEqual(decoded.assessment.riskLevel, "high")
        XCTAssertNil(decoded.assessment.wbgtC)
        XCTAssertTrue(decoded.assessment.reasonCodes.contains("heat_index_proxy_only"))
    }

    func testFamilyMemberListDecodes() throws {
        let json = """
        {
          "members": [
            {
              "id": "link-1",
              "ownerUserId": "user-1",
              "memberProfileId": "profile-child",
              "relation": "child",
              "label": "Mia"
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(FamilyMemberListResponse.self, from: json)
        XCTAssertEqual(decoded.members.count, 1)
        XCTAssertEqual(decoded.members[0].id, "link-1")
        XCTAssertEqual(decoded.members[0].memberProfileId, "profile-child")
        XCTAssertEqual(decoded.members[0].relation, "child")
        XCTAssertEqual(decoded.members[0].label, "Mia")
    }

    func testFamilyRiskOverviewDecodes() throws {
        let json = """
        {
          "ownerUserId": "user-1",
          "assessedAt": "2026-08-22T08:00:00Z",
          "highestRiskLevel": "high",
          "members": [
            {
              "memberLinkId": "link-1",
              "memberProfileId": "profile-child",
              "relation": "child",
              "label": "Mia",
              "riskLevel": "high",
              "riskScore": 70,
              "available": true,
              "unavailableReason": null
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(FamilyRiskOverviewResponse.self, from: json)
        XCTAssertEqual(decoded.highestRiskLevel, "high")
        XCTAssertEqual(decoded.members.count, 1)
        XCTAssertEqual(decoded.members[0].riskScore, 70)
    }
}
