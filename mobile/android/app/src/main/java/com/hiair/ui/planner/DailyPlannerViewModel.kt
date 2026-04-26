package com.hiair.ui.planner

import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.i18n.AndroidL10n
import org.json.JSONObject

data class PlannerState(
    val loading: Boolean = false,
    val statusText: String = "-",
    val safeWindows: List<String> = emptyList(),
    val hourly: List<String> = emptyList()
)

class DailyPlannerViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: PlannerState = PlannerState()
        private set

    fun refresh(userId: String, accessToken: String?, profileId: String, language: String = "ru") {
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
                    "${item.getString("type")}: ${item.getString("start")} -> ${item.getString("end")}"
                )
            }
            val hourlyItems = mutableListOf<String>()
            val hourly = json.getJSONArray("hourlyRisk")
            for (i in 0 until hourly.length()) {
                val item = hourly.getJSONObject(i)
                hourlyItems.add(
                    "${item.getString("hour")}: ${item.getString("overallRisk")}"
                )
            }
            state = state.copy(
                loading = false,
                statusText = AndroidL10n.t("planner.loaded_slots", language).replace("{count}", hourly.length().toString()),
                safeWindows = safeWindowItems,
                hourly = hourlyItems
            )
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                statusText = AndroidL10n.t("planner.failed", language),
                safeWindows = emptyList(),
                hourly = emptyList()
            )
        }
    }
}
