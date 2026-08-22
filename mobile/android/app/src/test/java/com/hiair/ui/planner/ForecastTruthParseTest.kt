package com.hiair.ui.planner

import com.hiair.ui.DashboardStatus
import com.hiair.ui.DashboardViewModel
import com.hiair.ui.design.HiAirHumanDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.util.Locale

class ForecastTruthParseTest {
    @Test
    fun dayPlanDecodesAdditiveMetadataAndPartialState() {
        val raw = """
            {
              "profileId": "profile-1",
              "timezone": "Europe/Madrid",
              "hourlyRisk": [{"hour": "2026-07-15T08:00:00+02:00", "overallRisk": "low"}],
              "safeWindows": [{"type": "walk", "start": "2026-07-15T08:00:00+02:00", "end": "2026-07-15T10:00:00+02:00", "confidence": 0.86}],
              "ventilationWindows": [],
              "dataQuality": "partial",
              "freshness": "cached",
              "forecastHours": 24,
              "forecastAvailable": true,
              "missingMetrics": ["pm10_ugm3"]
            }
        """.trimIndent()
        val state = DailyPlannerViewModel.parsePlan(raw, "en")
        assertTrue(state.forecastAvailable)
        assertTrue(state.statusText.contains("partial", ignoreCase = true))
        assertTrue(state.freshnessText.contains("cached", ignoreCase = true))
        assertEquals(1, state.hourly.size)
        assertEquals(1, state.safeWindows.size)
        assertFalse(state.hourly[0].startsWith("20:"))
        assertFalse(state.hourly[0].contains("T08"))
    }

    @Test
    fun emptyHourlyMarksForecastUnavailable() {
        val raw = """
            {
              "profileId": "profile-1",
              "timezone": "UTC",
              "hourlyRisk": [],
              "safeWindows": [],
              "ventilationWindows": [],
              "forecastAvailable": false
            }
        """.trimIndent()
        val state = DailyPlannerViewModel.parsePlan(raw, "en")
        assertFalse(state.forecastAvailable)
        assertTrue(state.statusText.contains("unavailable", ignoreCase = true))
        assertTrue(state.hourly.isEmpty())
    }

    @Test
    fun currentRiskTreatsNullOptionalMetricsAsMissing() {
        val raw = """
            {
              "profileId": "profile-1",
              "assessedAt": "2026-07-15T08:00:00+02:00",
              "freshness": "live",
              "environmental": {
                "lat": 41.39,
                "lon": 2.17,
                "temperature": 24.0,
                "feels_like": 25.0,
                "humidity": 50.0,
                "aqi": 40,
                "pm25": 8.0,
                "pm10": null,
                "ozone": null,
                "uv": null,
                "wind_speed": null,
                "source": "live",
                "timestamp": "2026-07-15T08:00:00+02:00",
                "timezone": "Europe/Madrid"
              },
              "risk": {
                "overallRisk": "low",
                "heatRisk": "low",
                "airRisk": "low",
                "outdoorRisk": "low",
                "indoorVentilationRisk": "low",
                "safeWindows": [
                  {"type": "walk", "start": "2026-07-15T08:00:00+02:00", "end": "2026-07-15T09:00:00+02:00", "confidence": 0.9}
                ],
                "recommendationFlags": [],
                "reasonCodes": []
              },
              "recommendation": {"headline": "Go", "summary": "ok", "actions": ["walk"]},
              "explanation": "ok",
              "explanationSource": "engine"
            }
        """.trimIndent()
        val state = DashboardViewModel.parseCurrentRisk(raw, "en")
        assertEquals(DashboardStatus.SUCCESS, state.status)
        assertEquals(40, state.aqi)
        assertEquals(8.0, state.pm25)
        assertNull(state.ozone)
        assertEquals("live", state.freshness)
        assertEquals("Europe/Madrid", state.timezone)
        assertFalse(state.safeWindows.first().contains("T08"))
    }

    @Test
    fun currentRiskParsesNo2WhenPresent() {
        val raw = """
            {
              "profileId": "profile-1",
              "assessedAt": "2026-07-15T08:00:00+02:00",
              "freshness": "live",
              "environmental": {
                "lat": 41.39,
                "lon": 2.17,
                "temperature": 24.0,
                "feels_like": 25.0,
                "humidity": 50.0,
                "aqi": 40,
                "pm25": 8.0,
                "ozone": 30.0,
                "no2": 55.0,
                "source": "live",
                "timestamp": "2026-07-15T08:00:00+02:00",
                "timezone": "Europe/Madrid"
              },
              "risk": {
                "overallRisk": "low",
                "heatRisk": "low",
                "airRisk": "low",
                "outdoorRisk": "low",
                "indoorVentilationRisk": "low",
                "safeWindows": [],
                "recommendationFlags": [],
                "reasonCodes": []
              },
              "recommendation": {"headline": "Go", "summary": "ok", "actions": ["walk"]},
              "explanation": "ok",
              "explanationSource": "engine"
            }
        """.trimIndent()
        val state = DashboardViewModel.parseCurrentRisk(raw, "en")
        assertEquals(55.0, state.no2)
    }

    @Test
    fun dayPlanParsesVentilationWindows() {
        val raw = """
            {
              "profileId": "profile-1",
              "timezone": "Europe/Madrid",
              "hourlyRisk": [{"hour": "2026-07-15T08:00:00+02:00", "overallRisk": "low"}],
              "safeWindows": [],
              "ventilationWindows": [
                {"type": "ventilation", "start": "2026-07-15T06:00:00+02:00", "end": "2026-07-15T07:00:00+02:00", "confidence": 0.8}
              ],
              "forecastAvailable": true
            }
        """.trimIndent()
        val state = DailyPlannerViewModel.parsePlan(raw, "en")
        assertEquals(1, state.ventilationWindows.size)
        assertFalse(state.ventilationWindows.first().contains("T06"))
    }

    @Test
    fun windowFormattingUsesForecastTimezone() {
        val madrid = ZoneId.of("Europe/Madrid")
        val range = HiAirHumanDate.timeRangeIso(
            "2026-07-15T08:00:00+02:00",
            "2026-07-15T09:00:00+02:00",
            Locale.UK,
            "—",
            madrid,
        )
        assertTrue(range.contains("08") || range.contains("8"))
        assertFalse(range.contains("T08"))
    }
}
