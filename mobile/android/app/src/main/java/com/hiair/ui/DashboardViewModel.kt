package com.hiair.ui

import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import org.json.JSONObject

enum class DashboardLoadState {
    IDLE,
    LOADING,
    SUCCESS,
    ERROR,
    NO_DATA
}

data class DashboardState(
    val loadState: DashboardLoadState = DashboardLoadState.IDLE,
    val riskScore: Int? = null,
    val riskLevel: String = "-",
    val explanation: String = "",
    val headline: String = "",
    val actions: List<String> = emptyList(),
    val safeWindows: List<String> = emptyList(),
    val morningBriefing: String = "",
    val breakdownLines: List<String> = emptyList(),
    val temperatureC: Double? = null,
    val aqi: Int? = null,
    val errorMessage: String = ""
)

class DashboardViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: DashboardState = DashboardState()
        private set

    fun refresh(
        userId: String,
        accessToken: String?,
        profileId: String?,
        persona: String,
        lat: Double,
        lon: Double,
        language: String,
        isGuest: Boolean
    ) {
        state = state.copy(loadState = DashboardLoadState.LOADING, errorMessage = "")
        try {
            if (!isGuest && !profileId.isNullOrBlank() && !userId.isBlank() && !accessToken.isNullOrBlank()) {
                refreshAuthenticated(userId, accessToken, profileId, persona, lat, lon, language)
            } else {
                refreshGuest(persona, lat, lon, language, userId, accessToken, profileId)
            }
        } catch (_: ApiHttpException) {
            state = state.copy(
                loadState = DashboardLoadState.ERROR,
                errorMessage = if (language == "en") "Unable to load dashboard data." else "Не удалось загрузить данные."
            )
        } catch (_: Exception) {
            state = state.copy(
                loadState = DashboardLoadState.ERROR,
                errorMessage = if (language == "en") "Network error." else "Ошибка сети."
            )
        }
    }

    private fun refreshAuthenticated(
        userId: String,
        accessToken: String,
        profileId: String,
        persona: String,
        lat: Double,
        lon: Double,
        language: String
    ) {
        val currentRiskRaw = apiClient.fetchCurrentRisk(
            userId = userId,
            accessToken = accessToken,
            profileId = profileId
        )
        val overviewJson = JSONObject(currentRiskRaw)
        val recommendation = overviewJson.getJSONObject("recommendation")
        val risk = overviewJson.getJSONObject("risk")
        val actions = jsonStringArray(recommendation.getJSONArray("actions"))
        val safeWindows = jsonSafeWindows(risk.getJSONArray("safeWindows"))
        val riskLevel = risk.getString("overallRisk")

        val briefingRaw = apiClient.fetchMorningBriefing(
            userId = userId,
            accessToken = accessToken,
            profileId = profileId,
            persona = persona,
            lat = lat,
            lon = lon
        )
        val briefingJson = JSONObject(briefingRaw)
        val breakdownRaw = apiClient.fetchRiskBreakdown(
            userId = userId,
            accessToken = accessToken,
            profileId = profileId,
            persona = persona,
            lat = lat,
            lon = lon
        )
        val breakdownJson = JSONObject(breakdownRaw)

        state = state.copy(
            loadState = DashboardLoadState.SUCCESS,
            riskScore = breakdownJson.getInt("total_score"),
            riskLevel = riskLevel,
            explanation = overviewJson.getString("explanation"),
            headline = recommendation.getString("headline"),
            actions = actions,
            safeWindows = safeWindows,
            morningBriefing = briefingJson.getString("summary"),
            breakdownLines = parseBreakdown(breakdownJson, language),
            temperatureC = briefingJson.getDouble("temperature_c"),
            aqi = briefingJson.getInt("aqi")
        )
    }

    private fun refreshGuest(
        persona: String,
        lat: Double,
        lon: Double,
        language: String,
        userId: String,
        accessToken: String?,
        profileId: String?
    ) {
        val briefingRaw = if (!userId.isBlank() && !accessToken.isNullOrBlank()) {
            apiClient.fetchMorningBriefing(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                persona = persona,
                lat = lat,
                lon = lon
            )
        } else {
            apiClient.fetchMorningBriefingPublic(persona = persona, lat = lat, lon = lon, language = language)
        }
        val briefingJson = JSONObject(briefingRaw)
        val breakdownRaw = if (!userId.isBlank() && !accessToken.isNullOrBlank()) {
            apiClient.fetchRiskBreakdown(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                persona = persona,
                lat = lat,
                lon = lon
            )
        } else {
            apiClient.fetchRiskBreakdownPublic(persona = persona, lat = lat, lon = lon)
        }
        val breakdownJson = JSONObject(breakdownRaw)
        val plannerRaw = apiClient.fetchDailyPlanner(persona = persona, lat = lat, lon = lon, hours = 12)
        val plannerJson = JSONObject(plannerRaw)
        val actions = mutableListOf<String>()
        if (briefingJson.has("best_walk_window") && !briefingJson.isNull("best_walk_window")) {
            val walk = briefingJson.getString("best_walk_window")
            actions.add(
                if (language == "en") "Best walk window: $walk" else "Лучшее время для прогулки: $walk"
            )
        }
        val hourly = plannerJson.getJSONArray("hourly")
        if (hourly.length() > 0) {
            val first = hourly.getJSONObject(0)
            val level = first.getString("level")
            actions.add(
                if (language == "en") "Current hourly risk: $level" else "Текущий почасовой риск: $level"
            )
        }

        state = state.copy(
            loadState = DashboardLoadState.SUCCESS,
            riskScore = breakdownJson.getInt("total_score"),
            riskLevel = breakdownJson.getString("risk_level"),
            explanation = briefingJson.getString("personal_note"),
            headline = if (language == "en") "Your air & heat briefing" else "Ваш брифинг по воздуху и жаре",
            actions = actions,
            safeWindows = parsePlannerSafeWindows(plannerJson),
            morningBriefing = briefingJson.getString("summary"),
            breakdownLines = parseBreakdown(breakdownJson, language),
            temperatureC = briefingJson.getDouble("temperature_c"),
            aqi = briefingJson.getInt("aqi")
        )
    }

    private fun jsonStringArray(array: org.json.JSONArray): List<String> {
        val items = mutableListOf<String>()
        for (index in 0 until array.length()) {
            items.add(array.getString(index))
        }
        return items
    }

    private fun jsonSafeWindows(array: org.json.JSONArray): List<String> {
        val items = mutableListOf<String>()
        for (index in 0 until array.length()) {
            val window = array.getJSONObject(index)
            items.add("${window.getString("type")}: ${window.getString("start")} -> ${window.getString("end")}")
        }
        return items
    }

    private fun parsePlannerSafeWindows(plannerJson: JSONObject): List<String> {
        val items = mutableListOf<String>()
        val array = plannerJson.getJSONArray("safe_windows")
        for (index in 0 until array.length()) {
            val window = array.getJSONObject(index)
            items.add("${window.getString("start_hour_iso")} -> ${window.getString("end_hour_iso")}")
        }
        return items
    }

    private fun parseBreakdown(breakdownJson: JSONObject, language: String): List<String> {
        val lines = mutableListOf<String>()
        val factors = breakdownJson.getJSONArray("factors")
        for (index in 0 until factors.length()) {
            val factor = factors.getJSONObject(index)
            val label = if (language == "en") factor.getString("label_en") else factor.getString("label_ru")
            lines.add("+${factor.getInt("points")} $label")
        }
        return lines
    }
}

fun DashboardState.dailyActionsText(): String {
    if (actions.isEmpty()) return ""
    return actions.joinToString(separator = "\n") { action -> "• $action" }
}

fun DashboardState.safeWindowsText(emptyLabel: String): String {
    if (safeWindows.isEmpty()) return emptyLabel
    return safeWindows.joinToString(separator = "\n") { window -> "• $window" }
}
