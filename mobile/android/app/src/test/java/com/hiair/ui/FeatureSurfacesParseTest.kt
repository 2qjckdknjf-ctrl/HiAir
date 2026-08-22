package com.hiair.ui

import com.hiair.ui.family.FamilyMembersParser
import com.hiair.ui.insights.AdaptationInsightsParser
import com.hiair.ui.settings.SettingsViewModel
import com.hiair.ui.work.WorkSiteRiskParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FeatureSurfacesParseTest {
    @Test
    fun hazardsParseOverallAndAvailableLines() {
        val raw = """
            {
              "profileId": "profile-1",
              "assessedAt": "2026-08-21T10:00:00Z",
              "assessment": {
                "profileId": "profile-1",
                "assessedAt": "2026-08-21T10:00:00Z",
                "overallLevel": "moderate",
                "overallScore": 52,
                "availableCount": 3,
                "hazards": [
                  {"hazard": "heat", "level": "high", "score": 70, "available": true},
                  {"hazard": "air", "level": "moderate", "score": 45, "available": true},
                  {"hazard": "pollen", "level": "unavailable", "score": 0, "available": false}
                ]
              }
            }
        """.trimIndent()
        val parsed = DashboardViewModel.parseHazards(raw)
        assertEquals("moderate", parsed.overallLevel)
        assertEquals(52, parsed.overallScore)
        assertEquals(3, parsed.lines.size)
        assertEquals(2, parsed.lines.count { it.available })
        assertEquals("heat", parsed.lines.first { it.available }.hazard)
    }

    @Test
    fun placesListAndCreateParseSavedPlaceFields() {
        val listRaw = """
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
                  "createdAt": "2026-08-21T12:00:00+00:00"
                }
              ]
            }
        """.trimIndent()
        val places = SettingsViewModel.parsePlacesList(listRaw)
        assertEquals(1, places.size)
        assertEquals("place-1", places[0].id)
        assertEquals("Home", places[0].name)
        assertEquals("home", places[0].placeType)
        assertEquals("Europe/Madrid", places[0].timezone)

        val createRaw = """
            {
              "id": "place-2",
              "userId": "user-1",
              "name": "Office",
              "placeType": "work",
              "lat": 40.42,
              "lon": -3.70
            }
        """.trimIndent()
        val created = SettingsViewModel.parseSavedPlace(createRaw)
        assertEquals("place-2", created.id)
        assertEquals("work", created.placeType)
    }

    @Test
    fun adaptationParseBaselinesAndProtectedDays() {
        val raw = """
            {
              "profileId": "profile-1",
              "generatedAt": "2026-08-21T12:00:00+00:00",
              "baselines": [
                {
                  "metric": "resting_heart_rate",
                  "window": "d7",
                  "value": 58.0,
                  "sampleSize": 6,
                  "confidence": 0.72,
                  "available": true
                },
                {
                  "metric": "hrv",
                  "window": "d30",
                  "value": null,
                  "sampleSize": 2,
                  "confidence": 0.1,
                  "available": false
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
        """.trimIndent()
        val parsed = AdaptationInsightsParser.parse(raw)
        assertEquals("profile-1", parsed.profileId)
        assertEquals(2, parsed.baselines.size)
        assertTrue(parsed.baselines.first().available)
        assertFalse(parsed.baselines[1].available)
        assertTrue(parsed.protectedDays.available)
        assertEquals(2, parsed.protectedDays.highRiskPeriodsAvoided)
        assertEquals(1, parsed.reasonCodes.size)
    }

    @Test
    fun siteRiskResponseParsesProxyDisclaimer() {
        val raw = """
            {
              "assessedAt": "2026-08-22T08:00:00Z",
              "assessment": {
                "siteId": "1:1",
                "wbgtC": null,
                "heatIndexC": 33.0,
                "workload": "moderate",
                "riskLevel": "high",
                "workRest": {"workMinutes": 30, "restMinutes": 30, "rationaleCodes": []},
                "availableMetrics": ["heat_index"],
                "missingMetrics": ["wbgt"],
                "reasonCodes": ["heat_index_proxy_only"]
              }
            }
        """.trimIndent()
        val parsed = WorkSiteRiskParser.parse(raw, "en")
        assertEquals("high", parsed.riskLevel)
        assertTrue(parsed.proxyOnly)
        assertTrue(parsed.summaryLine.contains("high"))
    }

    @Test
    fun familyMembersListParsesMemberFields() {
        val raw = """
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
        """.trimIndent()
        val members = FamilyMembersParser.parseList(raw)
        assertEquals(1, members.size)
        assertEquals("link-1", members[0].id)
        assertEquals("profile-child", members[0].memberProfileId)
        assertEquals("child", members[0].relation)
        assertEquals("Mia", members[0].label)
    }

    @Test
    fun dashboardElevatedRiskOnlyForHighLevels() {
        assertTrue(DashboardViewModel.isElevatedRisk("high"))
        assertTrue(DashboardViewModel.isElevatedRisk("very_high"))
        assertFalse(DashboardViewModel.isElevatedRisk("moderate"))
        assertFalse(DashboardViewModel.isElevatedRisk(null))
    }
}
