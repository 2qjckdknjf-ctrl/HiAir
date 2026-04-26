package com.hiair.ui

import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.i18n.AndroidL10n
import org.json.JSONObject

data class DashboardState(
    val loading: Boolean = false,
    val riskLevel: String = "-",
    val explanation: String = "-",
    val headline: String = "-",
    val actions: List<String> = emptyList(),
    val nearestSafeWindow: String = "-",
    val environmentSummary: String = "-",
    val dataSource: String = "-"
)

class DashboardViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: DashboardState = DashboardState()
        private set

    fun refresh(
        userId: String,
        accessToken: String?,
        profileId: String? = null,
        language: String = "ru"
    ) {
        if (profileId.isNullOrBlank()) {
            state = state.copy(
                loading = false,
                riskLevel = "unknown",
                explanation = AndroidL10n.t("planner.profile_required", language),
                headline = AndroidL10n.t("dashboard.create_profile_first", language),
                actions = emptyList(),
                nearestSafeWindow = "-",
                environmentSummary = "-",
                dataSource = "-"
            )
            return
        }
        state = state.copy(loading = true)
        try {
            val currentRiskRaw = apiClient.fetchCurrentRisk(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId
            )
            val overviewJson = JSONObject(currentRiskRaw)
            val recommendation = overviewJson.getJSONObject("recommendation")
            val risk = overviewJson.getJSONObject("risk")
            val environmental = overviewJson.getJSONObject("environmental")
            val actionsArray = recommendation.getJSONArray("actions")
            val actions = mutableListOf<String>()
            for (index in 0 until actionsArray.length()) {
                actions.add(actionsArray.getString(index))
            }
            val safeWindowsArray = risk.getJSONArray("safeWindows")
            val nearest = if (safeWindowsArray.length() > 0) {
                val first = safeWindowsArray.getJSONObject(0)
                "${first.getString("type")}: ${first.getString("start")} -> ${first.getString("end")}"
            } else {
                AndroidL10n.t("dashboard.no_safe_window", language)
            }
            state = state.copy(
                loading = false,
                riskLevel = risk.getString("overallRisk"),
                explanation = overviewJson.getString("explanation"),
                headline = recommendation.getString("headline"),
                actions = actions,
                nearestSafeWindow = nearest,
                environmentSummary = "${environmental.getDouble("temperature").toInt()}C • AQI ${environmental.getInt("aqi")}",
                dataSource = environmental.getString("source").uppercase()
            )
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                riskLevel = "error",
                explanation = AndroidL10n.t("dashboard.current_risk_failed", language),
                headline = AndroidL10n.t("dashboard.error", language),
                actions = emptyList(),
                nearestSafeWindow = "-",
                environmentSummary = "-",
                dataSource = "-"
            )
        }
    }
}

fun DashboardState.dailyActionsText(language: String): String {
    if (actions.isEmpty()) return AndroidL10n.t("dashboard.no_actions", language)
    return actions.joinToString(separator = "\n") { action -> "• $action" }
}
