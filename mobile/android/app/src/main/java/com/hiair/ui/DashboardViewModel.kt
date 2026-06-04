package com.hiair.ui

import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import org.json.JSONObject

data class DashboardState(
    val loading: Boolean = false,
    val riskLevel: String = "-",
    val explanation: String = "-",
    val headline: String = "-",
    val actions: List<String> = emptyList(),
    val nearestSafeWindow: String = "-",
    val wearableSteps: Int? = null,
    val wearableLoadLevel: String = "-",
    val wearableSummary: String = "-",
    val wearableConnected: Boolean = false
)

class DashboardViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: DashboardState = DashboardState()
        private set

    fun refresh(
        userId: String,
        accessToken: String?,
        profileId: String? = null
    ) {
        if (profileId.isNullOrBlank()) {
            state = state.copy(
                loading = false,
                riskLevel = "unknown",
                explanation = "Profile ID is required for personalized risk.",
                headline = "Create profile first",
                actions = emptyList(),
                nearestSafeWindow = "-"
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
                "No safe windows in the next hours."
            }
            var wearableSteps: Int? = null
            var wearableLoadLevel = "-"
            var wearableSummary = "-"
            var wearableConnected = false
            try {
                val wearableRaw = apiClient.fetchWearableToday(userId, accessToken)
                val wearableJson = JSONObject(wearableRaw)
                val daily = wearableJson.optJSONObject("dailySummary")
                if (daily != null && !daily.isNull("stepsTotal")) {
                    wearableSteps = daily.optInt("stepsTotal")
                }
                val load = wearableJson.optJSONObject("personalLoad")
                if (load != null) {
                    wearableLoadLevel = load.optString("level", "-")
                    val explanations = load.optJSONArray("explanations")
                    if (explanations != null && explanations.length() > 0) {
                        wearableSummary = explanations.getString(0)
                    }
                }
                wearableConnected = wearableJson.optJSONObject("consent")?.optBoolean("isActive") == true
            } catch (_: Exception) {
                // Wearable data optional — dashboard continues without it.
            }
            state = state.copy(
                loading = false,
                riskLevel = risk.getString("overallRisk"),
                explanation = overviewJson.getString("explanation"),
                headline = recommendation.getString("headline"),
                actions = actions,
                nearestSafeWindow = nearest,
                wearableSteps = wearableSteps,
                wearableLoadLevel = wearableLoadLevel,
                wearableSummary = wearableSummary,
                wearableConnected = wearableConnected
            )
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                riskLevel = "error",
                explanation = "Current risk request failed.",
                headline = "Unable to load dashboard data.",
                actions = emptyList(),
                nearestSafeWindow = "-"
            )
        }
    }
}

fun DashboardState.dailyActionsText(): String {
    if (actions.isEmpty()) return "No actions available."
    return actions.joinToString(separator = "\n") { action -> "• $action" }
}
