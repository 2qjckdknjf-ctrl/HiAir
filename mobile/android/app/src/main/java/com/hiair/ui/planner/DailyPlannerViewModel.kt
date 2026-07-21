package com.hiair.ui.planner

import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.i18n.AndroidL10n
import java.util.Locale
import org.json.JSONObject

data class PlannerState(
    val loading: Boolean = false,
    val statusText: String = "-",
    val safeWindows: List<String> = emptyList(),
    val hourly: List<String> = emptyList(),
    val peakLine: String = "",
    val premiumRequired: Boolean = false,
)

class DailyPlannerViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: PlannerState = PlannerState()
        private set

    fun refresh(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        state = state.copy(loading = true)
        try {
            val raw = apiClient.fetchAirDayPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId
            )
            val json = JSONObject(raw)
            val safeWindowItems = mutableListOf<String>()
            val safeWindows = json.getJSONArray("safeWindows")
            for (i in 0 until safeWindows.length()) {
                val item = safeWindows.getJSONObject(i)
                safeWindowItems.add(
                    formatSafeWindow(
                        type = item.getString("type"),
                        start = item.getString("start"),
                        end = item.getString("end"),
                        preferredLanguage = preferredLanguage,
                    )
                )
            }
            val hourlyItems = mutableListOf<String>()
            val hourly = json.getJSONArray("hourlyRisk")
            for (i in 0 until hourly.length()) {
                val item = hourly.getJSONObject(i)
                val hourLabel = humanHour(item.getString("hour"), preferredLanguage)
                val riskLabel = localizedRisk(item.getString("overallRisk"), preferredLanguage)
                hourlyItems.add("$hourLabel: $riskLabel")
            }
            val peakLine = buildPeakLine(hourly, preferredLanguage)
            state = state.copy(
                loading = false,
                statusText = l("planner.loaded", preferredLanguage)
                    .replaceFirst("%d", hourly.length().toString()),
                safeWindows = safeWindowItems,
                hourly = hourlyItems,
                peakLine = peakLine,
                premiumRequired = false,
            )
        } catch (error: ApiHttpException) {
            val premiumRequired = error.statusCode == 402
            state = state.copy(
                loading = false,
                statusText = if (premiumRequired) {
                    l("planner.premium_required", preferredLanguage)
                } else {
                    l("planner.failed", preferredLanguage)
                },
                safeWindows = emptyList(),
                hourly = emptyList(),
                peakLine = "",
                premiumRequired = premiumRequired,
            )
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                statusText = l("planner.failed", preferredLanguage),
                safeWindows = emptyList(),
                hourly = emptyList(),
                peakLine = "",
                premiumRequired = false,
            )
        }
    }

    private fun buildPeakLine(hourly: org.json.JSONArray, preferredLanguage: String): String {
        if (hourly.length() == 0) return ""
        var peakIndex = 0
        var peakWeight = -1
        for (i in 0 until hourly.length()) {
            val risk = hourly.getJSONObject(i).getString("overallRisk")
            val weight = riskWeight(risk)
            if (weight > peakWeight) {
                peakWeight = weight
                peakIndex = i
            }
        }
        val peak = hourly.getJSONObject(peakIndex)
        val riskLabel = localizedRisk(peak.getString("overallRisk"), preferredLanguage)
        val hourLabel = humanHour(peak.getString("hour"), preferredLanguage)
        return l("planner.peak_line", preferredLanguage)
            .replaceFirst("%@", riskLabel)
            .replaceFirst("%@", hourLabel)
    }

    private fun formatSafeWindow(type: String, start: String, end: String, preferredLanguage: String): String {
        val typeKey = when (type.lowercase()) {
            "walk", "outdoor", "safe", "sport", "exercise", "run" -> "planner.window.safe"
            "ventilation", "ventilate" -> "planner.window.ventilation"
            else -> "dashboard.safe_window"
        }
        val label = l(typeKey, preferredLanguage)
        val range = HiAirHumanDate.timeRangeIso(start, end, Locale.getDefault(), "")
        return if (range.isEmpty()) label else "$label: $range"
    }

    private fun humanHour(raw: String, preferredLanguage: String): String {
        val locale = Locale.forLanguageTag(preferredLanguage)
        HiAirHumanDate.formatIso(raw, locale, HiAirHumanDate.Style.TIME)?.let { return it }
        if (raw.length >= 2 && raw.substring(0, 2).all { it.isDigit() }) {
            return raw.take(5)
        }
        return raw
    }

    private fun localizedRisk(risk: String, preferredLanguage: String): String {
        return when (risk.lowercase()) {
            "low" -> l("dashboard.mood.calm", preferredLanguage)
            "moderate", "medium" -> l("dashboard.mood.aware", preferredLanguage)
            "high" -> l("dashboard.mood.cautious", preferredLanguage)
            "very_high", "very high" -> l("dashboard.mood.protective", preferredLanguage)
            else -> l("dashboard.mood.calm", preferredLanguage)
        }
    }

    private fun riskWeight(risk: String): Int {
        return when (risk.lowercase()) {
            "low" -> 1
            "moderate", "medium" -> 2
            "high" -> 3
            "very_high", "very high" -> 4
            else -> 0
        }
    }

    private fun l(key: String, preferredLanguage: String): String =
        AndroidL10n.t(key, preferredLanguage)
}
