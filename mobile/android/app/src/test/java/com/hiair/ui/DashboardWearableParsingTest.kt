package com.hiair.ui

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardWearableParsingTest {
    @Test
    fun parseWearableToday_connectedWithSteps() {
        val raw = """
            {
              "consent": { "isActive": true },
              "dailySummary": { "stepsTotal": 8430 },
              "personalLoad": {
                "level": "moderate",
                "explanations": ["Сегодня высокая активность на фоне жары."]
              }
            }
        """.trimIndent()
        val json = JSONObject(raw)
        val steps = json.optJSONObject("dailySummary")?.optInt("stepsTotal")
        val connected = json.optJSONObject("consent")?.optBoolean("isActive") == true
        val level = json.optJSONObject("personalLoad")?.optString("level")
        val summary = json.optJSONObject("personalLoad")?.optJSONArray("explanations")?.getString(0)

        assertTrue(connected)
        assertEquals(8430, steps)
        assertEquals("moderate", level)
        assertTrue(summary?.contains("активност") == true)
    }

    @Test
    fun parseWearableToday_notConnected() {
        val raw = """{"consent": null, "dailySummary": null}"""
        val json = JSONObject(raw)
        assertTrue(json.isNull("dailySummary"))
    }
}
