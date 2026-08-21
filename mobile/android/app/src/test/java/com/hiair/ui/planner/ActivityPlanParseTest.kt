package com.hiair.ui.planner

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityPlanParseTest {
    @Test
    fun activityCatalogParsesDefaults() {
        val raw = """
            {
              "activities": [
                {"activity": "running", "defaultDurationMinutes": 45, "defaultIntensity": "high", "outdoor": true},
                {"activity": "ventilation", "defaultDurationMinutes": 60, "defaultIntensity": "low", "outdoor": false}
              ]
            }
        """.trimIndent()
        val catalog = DailyPlannerViewModel.parseActivityCatalog(raw)
        assertEquals(2, catalog.size)
        assertEquals("running", catalog[0].id)
        assertEquals(45, catalog[0].defaultDurationMinutes)
        assertFalse(catalog[1].outdoor)
    }

    @Test
    fun activityPlanParsesWindowsAndRecommendedStart() {
        val raw = """
            {
              "profileId": "profile-1",
              "activity": "running",
              "intensity": "high",
              "durationMinutes": 45,
              "timezone": "Europe/Madrid",
              "forecastAvailable": true,
              "windows": [
                {"tier": "best", "start": "2026-08-21T07:00:00+02:00", "end": "2026-08-21T09:00:00+02:00", "score": 88, "reasonCodes": ["good_air"], "confidence": 0.9},
                {"tier": "avoid", "start": "2026-08-21T14:00:00+02:00", "end": "2026-08-21T16:00:00+02:00", "score": 20, "reasonCodes": ["heat"], "confidence": 0.8}
              ],
              "recommendedStart": "2026-08-21T07:00:00+02:00"
            }
        """.trimIndent()
        val parsed = DailyPlannerViewModel.parseActivityPlan(raw, "en")
        assertTrue(parsed.forecastAvailable)
        assertEquals(2, parsed.windows.size)
        assertTrue(parsed.windows[0].line.startsWith("Best"))
        assertTrue(parsed.windows[1].line.startsWith("Avoid"))
        assertFalse(parsed.windows[0].line.contains("T07"))
        assertTrue(parsed.recommendedStart.isNotBlank())
        assertFalse(parsed.recommendedStart.contains("T07"))
    }

    @Test
    fun activityPlanHonestWhenForecastUnavailable() {
        val raw = """
            {
              "profileId": "profile-1",
              "activity": "walking",
              "intensity": "low",
              "durationMinutes": 30,
              "timezone": "UTC",
              "forecastAvailable": false,
              "windows": []
            }
        """.trimIndent()
        val parsed = DailyPlannerViewModel.parseActivityPlan(raw, "en")
        assertFalse(parsed.forecastAvailable)
        assertTrue(parsed.windows.isEmpty())
        assertTrue(parsed.statusText.contains("unavailable", ignoreCase = true))
    }
}
