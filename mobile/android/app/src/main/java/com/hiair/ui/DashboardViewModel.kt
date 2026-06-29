package com.hiair.ui

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import java.io.IOException
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
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
    val temperatureC: Double? = null,
    val feelsLikeC: Double? = null,
    val humidityPercent: Double? = null,
    val wearableSteps: Int? = null,
    val wearableLoadLevel: String? = null,
    val wearableSummary: String? = null,
    val wearableConnected: Boolean = false,
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
    fun load(userId: String, accessToken: String?, profileId: String?, isRetry: Boolean = false) {
        if (isRetry) {
            ProductAnalytics.track("dashboard_retry")
        }
        if (userId.isBlank() || accessToken.isNullOrBlank() || profileId.isNullOrBlank()) {
            state = DashboardState(status = DashboardStatus.EMPTY)
            return
        }
        state = state.copy(status = DashboardStatus.LOADING)
        ProductAnalytics.track("dashboard_loading")
        try {
            val raw = apiClient.fetchCurrentRisk(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
            )
            val parsed = parseCurrentRisk(raw)
            state = withWearable(parsed, userId, accessToken)
            ProductAnalytics.track(
                "dashboard_loaded",
                mapOf("source" to (state.dataSource ?: "unknown")),
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
        }
    }

    private fun parseCurrentRisk(raw: String): DashboardState {
        val json = JSONObject(raw)
        val risk = json.optJSONObject("risk")
            ?: throw IllegalStateException("current-risk response missing 'risk'")
        val level = risk.optString("overallRisk", "")
        if (level.isBlank()) {
            throw IllegalStateException("current-risk response missing 'overallRisk'")
        }
        val recommendation = json.optJSONObject("recommendation")
        val environment = json.optJSONObject("environmental")

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
                    val label = if (type.isNotBlank()) "$type: $start → $end" else "$start → $end"
                    safeWindows.add(label)
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
            aqi = environment?.takeIf { it.has("aqi") }?.optInt("aqi"),
            pm25 = environment?.takeIf { it.has("pm25") }?.optDouble("pm25"),
            ozone = environment?.takeIf { it.has("ozone") }?.optDouble("ozone"),
            temperatureC = environment?.takeIf { it.has("temperature") }?.optDouble("temperature"),
            feelsLikeC = environment?.takeIf { it.has("feels_like") }?.optDouble("feels_like"),
            humidityPercent = environment?.takeIf { it.has("humidity") }?.optDouble("humidity"),
        )
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
            base.copy(
                wearableSteps = steps,
                wearableLoadLevel = loadLevel,
                wearableSummary = summary,
                wearableConnected = connected,
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
    }
}
