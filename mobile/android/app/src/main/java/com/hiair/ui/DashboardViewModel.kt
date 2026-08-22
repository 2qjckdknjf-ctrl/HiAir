package com.hiair.ui

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.family.FamilyMemberRiskItem
import com.hiair.ui.family.FamilyRiskParser
import com.hiair.ui.i18n.AndroidL10n
import java.io.IOException
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.time.ZoneId
import java.util.Locale
import org.json.JSONObject

/**
 * Single source of truth for the dashboard screen. The screen is always in
 * exactly one of these states; the renderer paints purely from this state and
 * never substitutes placeholder/demo values.
 */
enum class DashboardStatus {
    INITIAL,
    LOADING,
    SUCCESS,
    EMPTY,
    ERROR,
    OFFLINE,
}

data class HazardLine(
    val hazard: String,
    val level: String,
    val score: Int,
    val available: Boolean,
)

data class DashboardState(
    val status: DashboardStatus = DashboardStatus.INITIAL,
    val riskLevel: String? = null,
    val riskScore: Int? = null,
    val headline: String? = null,
    val explanation: String? = null,
    val actions: List<String> = emptyList(),
    val safeWindows: List<String> = emptyList(),
    val dataSource: String? = null,
    val aqi: Int? = null,
    val pm25: Double? = null,
    val ozone: Double? = null,
    val no2: Double? = null,
    val temperatureC: Double? = null,
    val feelsLikeC: Double? = null,
    val humidityPercent: Double? = null,
    val freshness: String? = null,
    val dataQuality: String? = null,
    val timezone: String? = null,
    val wearableSteps: Int? = null,
    val wearableLoadLevel: String? = null,
    val wearableSummary: String? = null,
    val wearableConnected: Boolean = false,
    val healthSummaryRaw: String? = null,
    val hazardsOverallLevel: String? = null,
    val hazardsOverallScore: Int? = null,
    val hazardLines: List<HazardLine> = emptyList(),
    val familyRiskLines: List<FamilyMemberRiskItem> = emptyList(),
    val familyHighestRisk: String? = null,
    val exposureReducedMarked: Boolean = false,
    val highRiskAvoidedMarked: Boolean = false,
    val protectedDayStatus: String = "",
)

class DashboardViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: DashboardState = DashboardState()
        private set

    /**
     * Marks the screen as loading on the UI thread before the background load
     * starts. This prevents a re-render from spawning a duplicate request while
     * the first one is still in flight.
     */
    fun markLoading() {
        state = state.copy(status = DashboardStatus.LOADING)
    }

    /** Resets the screen to its initial state, e.g. after sign-out. */
    fun reset() {
        state = DashboardState()
    }

    /**
     * Loads real risk data for the given profile. Must be called from a
     * background thread. On failure the previous values are discarded so the UI
     * never presents stale data as fresh.
     */
    fun load(
        userId: String,
        accessToken: String?,
        profileId: String?,
        preferredLanguage: String,
        isRetry: Boolean = false,
        onRiskReady: (() -> Unit)? = null,
    ) {
        if (isRetry) {
            ProductAnalytics.track("dashboard_retry")
        }
        if (userId.isBlank() || accessToken.isNullOrBlank() || profileId.isNullOrBlank()) {
            state = DashboardState(status = DashboardStatus.EMPTY)
            return
        }
        state = state.copy(
            status = DashboardStatus.LOADING,
            exposureReducedMarked = false,
            highRiskAvoidedMarked = false,
            protectedDayStatus = "",
        )
        ProductAnalytics.track("dashboard_loading")
        ProductAnalytics.track("forecast_fetch_started", mapOf("surface" to "dashboard"))
        try {
            val raw = apiClient.fetchCurrentRisk(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
            )
            val parsed = parseCurrentRisk(raw, preferredLanguage)
            // Paint risk immediately; wearable/health enrich without blocking SUCCESS.
            state = parsed
            ProductAnalytics.track(
                "dashboard_loaded",
                mapOf("source" to (parsed.dataSource ?: "unknown")),
            )
            ProductAnalytics.track(
                "forecast_fetch_succeeded",
                mapOf(
                    "freshness" to (parsed.freshness ?: parsed.dataSource ?: ""),
                    "quality" to (parsed.dataQuality ?: ""),
                    "hours" to parsed.safeWindows.size.toString(),
                ),
            )
            onRiskReady?.invoke()
            state = withFamilyRisk(
                withHazards(
                    withWearable(parsed, userId, accessToken),
                    userId,
                    accessToken,
                    profileId,
                ),
                userId,
                accessToken,
            )
        } catch (error: Exception) {
            val offline = isOffline(error)
            state = DashboardState(
                status = if (offline) DashboardStatus.OFFLINE else DashboardStatus.ERROR,
            )
            ProductAnalytics.track(
                "dashboard_failed",
                mapOf("offline" to offline.toString()),
            )
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "dashboard"))
        }
    }

    private fun withHazards(
        base: DashboardState,
        userId: String,
        accessToken: String?,
        profileId: String,
    ): DashboardState {
        return try {
            val raw = apiClient.fetchHazards(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
            )
            val parsed = parseHazards(raw)
            base.copy(
                hazardsOverallLevel = parsed.overallLevel,
                hazardsOverallScore = parsed.overallScore,
                hazardLines = parsed.lines,
            )
        } catch (_: Exception) {
            base
        }
    }

    private fun withFamilyRisk(
        base: DashboardState,
        userId: String,
        accessToken: String?,
    ): DashboardState {
        return try {
            val raw = apiClient.fetchFamilyRiskOverview(userId, accessToken)
            val members = FamilyRiskParser.parseOverview(raw)
            val highest = JSONObject(raw).optString("highestRiskLevel").takeIf { it.isNotBlank() }
            base.copy(
                familyRiskLines = members,
                familyHighestRisk = highest,
            )
        } catch (_: Exception) {
            base
        }
    }

    private fun withWearable(base: DashboardState, userId: String, accessToken: String?): DashboardState {
        return try {
            val wearableJson = JSONObject(apiClient.fetchWearableToday(userId, accessToken))
            val daily = wearableJson.optJSONObject("dailySummary")
            val steps = if (daily != null && !daily.isNull("stepsTotal")) daily.optInt("stepsTotal") else null
            val load = wearableJson.optJSONObject("personalLoad")
            val loadLevel = load?.optString("level")?.takeIf { it.isNotBlank() }
            val summary = load?.optJSONArray("explanations")
                ?.takeIf { it.length() > 0 }
                ?.optString(0)
                ?.takeIf { it.isNotBlank() }
            val connected = wearableJson.optJSONObject("consent")?.optBoolean("isActive") == true
            val healthSummaryRaw = if (connected) {
                runCatching {
                    apiClient.fetchHealthSummary(userId, accessToken)
                }.getOrNull()
            } else {
                null
            }
            base.copy(
                wearableSteps = steps,
                wearableLoadLevel = loadLevel,
                wearableSummary = summary,
                wearableConnected = connected,
                healthSummaryRaw = healthSummaryRaw,
            )
        } catch (_: Exception) {
            // Wearable data is optional; the dashboard remains valid without it.
            base
        }
    }

    private fun isOffline(error: Throwable): Boolean {
        return when (error) {
            is UnknownHostException,
            is ConnectException,
            is SocketTimeoutException,
            is SocketException,
            is IOException -> true
            else -> false
        }
    }

    companion object {
        fun parseCurrentRisk(raw: String, preferredLanguage: String): DashboardState {
            val json = JSONObject(raw)
            val risk = json.optJSONObject("risk")
                ?: throw IllegalStateException("current-risk response missing 'risk'")
            val level = risk.optString("overallRisk", "")
            if (level.isBlank()) {
                throw IllegalStateException("current-risk response missing 'overallRisk'")
            }
            val recommendation = json.optJSONObject("recommendation")
            val environment = json.optJSONObject("environmental")
            val timezone = environment?.optString("timezone")?.takeIf { it.isNotBlank() }
            val zoneId = HiAirHumanDate.zoneId(timezone)
            val freshness = json.optString("freshness").takeIf { it.isNotBlank() }
                ?: environment?.optString("source")?.takeIf { it.isNotBlank() }
            val dataQuality = json.optString("dataQuality").takeIf { it.isNotBlank() }

            val actions = mutableListOf<String>()
            recommendation?.optJSONArray("actions")?.let { array ->
                for (index in 0 until array.length()) {
                    array.optString(index).takeIf { it.isNotBlank() }?.let(actions::add)
                }
            }

            val safeWindows = mutableListOf<String>()
            risk.optJSONArray("safeWindows")?.let { array ->
                for (index in 0 until array.length()) {
                    val window = array.optJSONObject(index) ?: continue
                    val type = window.optString("type")
                    val start = window.optString("start")
                    val end = window.optString("end")
                    if (start.isNotBlank() && end.isNotBlank()) {
                        safeWindows.add(formatSafeWindow(type, start, end, preferredLanguage, zoneId))
                    }
                }
            }
            // Additive ventilation list — keep labeled separately from outdoor windows.
            risk.optJSONArray("ventilationWindows")?.let { array ->
                for (index in 0 until array.length()) {
                    val window = array.optJSONObject(index) ?: continue
                    val start = window.optString("start")
                    val end = window.optString("end")
                    if (start.isNotBlank() && end.isNotBlank()) {
                        safeWindows.add(
                            formatSafeWindow(
                                type = window.optString("type", "ventilation"),
                                start = start,
                                end = end,
                                preferredLanguage = preferredLanguage,
                                zoneId = zoneId,
                            )
                        )
                    }
                }
            }

            return DashboardState(
                status = DashboardStatus.SUCCESS,
                riskLevel = level,
                riskScore = scoreForLevel(level),
                headline = recommendation?.optString("headline")?.takeIf { it.isNotBlank() },
                explanation = json.optString("explanation").takeIf { it.isNotBlank() },
                actions = actions,
                safeWindows = safeWindows,
                dataSource = environment?.optString("source")?.takeIf { it.isNotBlank() },
                aqi = environment.optionalInt("aqi"),
                pm25 = environment.optionalDouble("pm25"),
                ozone = environment.optionalDouble("ozone"),
                no2 = environment.optionalDouble("no2"),
                temperatureC = environment.optionalDouble("temperature"),
                feelsLikeC = environment.optionalDouble("feels_like"),
                humidityPercent = environment.optionalDouble("humidity"),
                freshness = freshness,
                dataQuality = dataQuality,
                timezone = timezone,
            )
        }

        data class ParsedHazards(
            val overallLevel: String,
            val overallScore: Int,
            val lines: List<HazardLine>,
        )

        fun parseHazards(raw: String): ParsedHazards {
            val json = JSONObject(raw)
            val assessment = json.optJSONObject("assessment")
                ?: throw IllegalStateException("hazards response missing 'assessment'")
            val overallLevel = assessment.optString("overallLevel", "")
            if (overallLevel.isBlank()) {
                throw IllegalStateException("hazards response missing 'overallLevel'")
            }
            val lines = mutableListOf<HazardLine>()
            assessment.optJSONArray("hazards")?.let { array ->
                for (index in 0 until array.length()) {
                    val row = array.getJSONObject(index)
                    lines.add(
                        HazardLine(
                            hazard = row.optString("hazard"),
                            level = row.optString("level"),
                            score = row.optInt("score", 0),
                            available = row.optBoolean("available", false),
                        ),
                    )
                }
            }
            return ParsedHazards(
                overallLevel = overallLevel,
                overallScore = assessment.optInt("overallScore", 0),
                lines = lines,
            )
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
            val label = AndroidL10n.t(typeKey, preferredLanguage)
            val range = HiAirHumanDate.timeRangeIso(start, end, Locale.getDefault(), "", zoneId)
            return if (range.isEmpty()) label else "$label: $range"
        }

        /**
         * Canonical numeric encoding of the backend risk level, matching the
         * server's RISK_LEVEL_TO_SCORE mapping. This is a deterministic visual
         * representation of the real categorical risk, not synthetic data.
         */
        fun scoreForLevel(level: String): Int {
            return when (level.lowercase()) {
                "low" -> 20
                "moderate", "medium" -> 45
                "high" -> 70
                "very_high", "very high" -> 90
                else -> 45
            }
        }

        fun isElevatedRisk(level: String?): Boolean {
            val normalized = level?.lowercase()?.replace(' ', '_') ?: return false
            return normalized == "high" || normalized == "very_high"
        }
    }

    fun markExposureReduced(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        recordProtectedDayEvent(
            userId, accessToken, profileId, preferredLanguage,
            "poor_air_exposure_reduced",
            "dashboard.protected.exposure_done",
        ) { marked, status ->
            state = state.copy(exposureReducedMarked = marked, protectedDayStatus = status)
        }
    }

    fun markHighRiskAvoided(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        recordProtectedDayEvent(
            userId, accessToken, profileId, preferredLanguage,
            "high_risk_period_avoided",
            "dashboard.protected.risk_avoided_done",
        ) { marked, status ->
            state = state.copy(highRiskAvoidedMarked = marked, protectedDayStatus = status)
        }
    }

    private fun recordProtectedDayEvent(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
        eventType: String,
        successKey: String,
        onResult: (marked: Boolean, status: String) -> Unit,
    ) {
        if (userId.isBlank() || profileId.isBlank()) return
        try {
            apiClient.createProtectedDayEvent(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                eventType = eventType,
            )
            onResult(true, AndroidL10n.t(successKey, preferredLanguage))
        } catch (_: Exception) {
            onResult(false, AndroidL10n.t("planner.activity.mark_planned_failed", preferredLanguage))
        }
    }
}

private fun JSONObject?.optionalInt(key: String): Int? {
    if (this == null || !has(key) || isNull(key)) return null
    return optInt(key)
}

private fun JSONObject?.optionalDouble(key: String): Double? {
    if (this == null || !has(key) || isNull(key)) return null
    return optDouble(key)
}
