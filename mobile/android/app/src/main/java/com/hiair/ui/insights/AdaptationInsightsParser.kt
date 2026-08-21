package com.hiair.ui.insights

import org.json.JSONObject

data class AdaptationBaselineLine(
    val metric: String,
    val window: String,
    val value: Double?,
    val sampleSize: Int,
    val confidence: Double,
    val available: Boolean,
)

data class AdaptationProtectedDays(
    val highRiskPeriodsAvoided: Int,
    val workoutsMoved: Int,
    val ventilationWindowsUsed: Int,
    val poorAirExposureReduced: Int,
    val available: Boolean,
)

data class AdaptationSnapshot(
    val profileId: String,
    val generatedAt: String,
    val baselines: List<AdaptationBaselineLine>,
    val protectedDays: AdaptationProtectedDays,
    val reasonCodes: List<String>,
)

object AdaptationInsightsParser {
    fun parse(raw: String): AdaptationSnapshot {
        val json = JSONObject(raw)
        val baselines = mutableListOf<AdaptationBaselineLine>()
        json.optJSONArray("baselines")?.let { array ->
            for (index in 0 until array.length()) {
                val row = array.getJSONObject(index)
                baselines.add(
                    AdaptationBaselineLine(
                        metric = row.optString("metric"),
                        window = row.optString("window"),
                        value = row.optionalDouble("value"),
                        sampleSize = row.optInt("sampleSize", 0),
                        confidence = row.optDouble("confidence", 0.0),
                        available = row.optBoolean("available", false),
                    ),
                )
            }
        }
        val protected = json.optJSONObject("protectedDays") ?: JSONObject()
        return AdaptationSnapshot(
            profileId = json.optString("profileId"),
            generatedAt = json.optString("generatedAt"),
            baselines = baselines,
            protectedDays = AdaptationProtectedDays(
                highRiskPeriodsAvoided = protected.optInt("highRiskPeriodsAvoided", 0),
                workoutsMoved = protected.optInt("workoutsMoved", 0),
                ventilationWindowsUsed = protected.optInt("ventilationWindowsUsed", 0),
                poorAirExposureReduced = protected.optInt("poorAirExposureReduced", 0),
                available = protected.optBoolean("available", false),
            ),
            reasonCodes = json.optStringArray("reasonCodes"),
        )
    }

    private fun JSONObject.optionalDouble(key: String): Double? {
        if (!has(key) || isNull(key)) return null
        return optDouble(key)
    }

    private fun JSONObject.optStringArray(key: String): List<String> {
        val array = optJSONArray(key) ?: return emptyList()
        return buildList {
            for (index in 0 until array.length()) {
                array.optString(index).takeIf { it.isNotBlank() }?.let(::add)
            }
        }
    }
}
