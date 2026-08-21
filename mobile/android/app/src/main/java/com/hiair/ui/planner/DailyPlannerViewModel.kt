package com.hiair.ui.planner

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.i18n.AndroidL10n
import java.time.ZoneId
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

data class PlannerState(
    val loading: Boolean = false,
    val statusText: String = "-",
    val freshnessText: String = "",
    val safeWindows: List<String> = emptyList(),
    val hourly: List<String> = emptyList(),
    val peakLine: String = "",
    val premiumRequired: Boolean = false,
    val forecastAvailable: Boolean = true,
    val dataQuality: String = "",
    val freshness: String = "",
)

class DailyPlannerViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: PlannerState = PlannerState()
        private set

    fun refresh(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        state = state.copy(loading = true)
        ProductAnalytics.track("forecast_fetch_started", mapOf("surface" to "planner"))
        try {
            val raw = apiClient.fetchAirDayPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId
            )
            state = parsePlan(raw, preferredLanguage)
            if (!state.forecastAvailable) {
                ProductAnalytics.track(
                    "planner_forecast_unavailable",
                    mapOf("quality" to state.dataQuality.ifBlank { "unknown" }),
                )
            } else {
                ProductAnalytics.track(
                    "planner_real_forecast_loaded",
                    mapOf(
                        "quality" to state.dataQuality.ifBlank { "complete" },
                        "hours" to state.hourly.size.toString(),
                        "freshness" to state.freshness,
                    ),
                )
            }
        } catch (error: ApiHttpException) {
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "planner"))
            val premiumRequired = error.statusCode == 402
            state = state.copy(
                loading = false,
                statusText = if (premiumRequired) {
                    l("planner.premium_required", preferredLanguage)
                } else {
                    l("planner.failed", preferredLanguage)
                },
                freshnessText = "",
                safeWindows = emptyList(),
                hourly = emptyList(),
                peakLine = "",
                premiumRequired = premiumRequired,
                forecastAvailable = false,
            )
        } catch (_: Exception) {
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "planner"))
            state = state.copy(
                loading = false,
                statusText = l("planner.failed", preferredLanguage),
                freshnessText = "",
                safeWindows = emptyList(),
                hourly = emptyList(),
                peakLine = "",
                premiumRequired = false,
                forecastAvailable = false,
            )
        }
    }

    companion object {
        fun parsePlan(raw: String, preferredLanguage: String): PlannerState {
            val json = JSONObject(raw)
            val timezone = json.optString("timezone").takeIf { it.isNotBlank() }
            val zoneId = HiAirHumanDate.zoneId(timezone)
            val hourly = json.optJSONArray("hourlyRisk") ?: JSONArray()
            val forecastAvailable = if (json.has("forecastAvailable") && !json.isNull("forecastAvailable")) {
                json.optBoolean("forecastAvailable")
            } else {
                hourly.length() > 0
            }
            val dataQuality = json.optString("dataQuality")
            val freshness = json.optString("freshness")

            val safeWindowItems = mutableListOf<String>()
            val safeWindows = json.optJSONArray("safeWindows") ?: JSONArray()
            for (i in 0 until safeWindows.length()) {
                val item = safeWindows.getJSONObject(i)
                safeWindowItems.add(
                    formatSafeWindow(
                        type = item.getString("type"),
                        start = item.getString("start"),
                        end = item.getString("end"),
                        preferredLanguage = preferredLanguage,
                        zoneId = zoneId,
                    )
                )
            }
            val hourlyItems = mutableListOf<String>()
            for (i in 0 until hourly.length()) {
                val item = hourly.getJSONObject(i)
                val hourLabel = humanHour(item.getString("hour"), preferredLanguage, zoneId)
                val riskLabel = localizedRisk(item.getString("overallRisk"), preferredLanguage)
                hourlyItems.add("$hourLabel: $riskLabel")
            }
            val statusText = when {
                !forecastAvailable -> l("planner.forecast_unavailable", preferredLanguage)
                dataQuality.equals("partial", ignoreCase = true) ->
                    l("planner.forecast_partial", preferredLanguage)
                else -> l("planner.loaded", preferredLanguage)
                    .replaceFirst("%d", hourly.length().toString())
            }
            val freshnessText = if (forecastAvailable) freshnessCaption(freshness, preferredLanguage) else ""
            return PlannerState(
                loading = false,
                statusText = statusText,
                freshnessText = freshnessText,
                safeWindows = safeWindowItems,
                hourly = hourlyItems,
                peakLine = buildPeakLine(hourly, preferredLanguage, zoneId),
                premiumRequired = false,
                forecastAvailable = forecastAvailable,
                dataQuality = dataQuality,
                freshness = freshness,
            )
        }

        private fun freshnessCaption(freshness: String, preferredLanguage: String): String {
            return when (freshness.lowercase()) {
                "cached" -> l("planner.freshness.cached", preferredLanguage)
                "stale" -> l("planner.freshness.stale", preferredLanguage)
                "live" -> l("planner.freshness.live", preferredLanguage)
                else -> if (freshness.isBlank()) "" else l("planner.freshness.live", preferredLanguage)
            }
        }

        private fun buildPeakLine(hourly: JSONArray, preferredLanguage: String, zoneId: ZoneId): String {
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
            val hourLabel = humanHour(peak.getString("hour"), preferredLanguage, zoneId)
            return l("planner.peak_line", preferredLanguage)
                .replaceFirst("%@", riskLabel)
                .replaceFirst("%@", hourLabel)
        }

        private fun formatSafeWindow(
            type: String,
            start: String,
            end: String,
            preferredLanguage: String,
            zoneId: ZoneId,
        ): String {
            val typeKey = when (type.lowercase()) {
                "walk", "outdoor", "safe", "sport", "exercise", "run" -> "planner.window.safe"
                "ventilation", "ventilate" -> "planner.window.ventilation"
                else -> "dashboard.safe_window"
            }
            val label = l(typeKey, preferredLanguage)
            val range = HiAirHumanDate.timeRangeIso(
                start,
                end,
                Locale.getDefault(),
                "",
                zoneId,
            )
            return if (range.isEmpty()) label else "$label: $range"
        }

        private fun humanHour(raw: String, preferredLanguage: String, zoneId: ZoneId): String {
            val locale = Locale.forLanguageTag(preferredLanguage)
            HiAirHumanDate.formatIso(raw, locale, HiAirHumanDate.Style.TIME, zoneId)?.let { return it }
            if (raw.length >= 2 && raw.substring(0, 2).all { it.isDigit() } && !raw.contains("T")) {
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
}
