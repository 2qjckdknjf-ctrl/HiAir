package com.hiair.ui.symptoms

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SymptomTaxonomyParseTest {
    @Test
    fun prefersSafetyNoticeOverSeverityNotice() {
        val json = JSONObject(
            """
            {
              "safetyNotice": "Preferred",
              "severityNotice": "Legacy",
              "categories": [
                {
                  "id": "respiratory",
                  "label": "Breathing",
                  "symptoms": [
                    {"symptomType": "cough", "label": "Cough", "redFlag": false}
                  ]
                }
              ],
              "count": 1
            }
            """.trimIndent(),
        )
        val notice = json.optString("safetyNotice").ifBlank { json.optString("severityNotice") }
        assertEquals("Preferred", notice)
        assertEquals(1, json.optInt("count"))
        assertTrue(json.getJSONArray("categories").length() > 0)
    }

    @Test
    fun acceptsProductionSeverityNoticeAlias() {
        val json = JSONObject(
            """
            {
              "severityNotice": "Wellness notice",
              "categories": [
                {
                  "id": "general",
                  "label": "General",
                  "symptoms": [
                    {"symptomType": "fatigue", "label": "Fatigue", "redFlag": false}
                  ]
                }
              ],
              "count": 1
            }
            """.trimIndent(),
        )
        val notice = json.optString("safetyNotice").ifBlank { json.optString("severityNotice") }
        assertEquals("Wellness notice", notice)
    }
}
