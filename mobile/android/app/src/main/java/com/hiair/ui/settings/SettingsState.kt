package com.hiair.ui.settings

import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.network.ApiHttpException
import com.hiair.ui.i18n.AndroidL10n
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import org.json.JSONObject

data class SettingsState(
    val email: String = "",
    val password: String = "",
    val userId: String = "",
    val accessToken: String = "",
    val pushAlertsEnabled: Boolean = true,
    val alertThreshold: String = "high",
    val quietHoursStart: Int = 22,
    val quietHoursEnd: Int = 7,
    val profileBasedAlerting: Boolean = true,
    val preferredLanguage: String = "ru",
    val defaultPersona: String = "adult",
    val subscriptionPlans: List<Pair<String, String>> = emptyList(),
    val selectedPlanId: String = "basic_monthly",
    val subscriptionStatus: String = "inactive",
    val aiSummaryHours: Int = 24,
    val aiSummaryText: String = "-",
    val aiTrendText: String = "-",
    val aiTrendGraphText: String = "-",
    val aiTrendPoints: List<Int> = emptyList(),
    val aiTrendFallbackPoints: List<Int> = emptyList(),
    val aiTrendGuardrailPoints: List<Int> = emptyList(),
    val aiTrendErrorPoints: List<Int> = emptyList(),
    val aiTrendTimeoutPoints: List<Int> = emptyList(),
    val aiTrendNetworkPoints: List<Int> = emptyList(),
    val aiTrendServerPoints: List<Int> = emptyList(),
    val aiChartMetric: String = "total",
    val aiChartMode: String = "bars",
    val aiTrendStartLabel: String = "-",
    val aiTrendEndLabel: String = "-",
    val aiRequestInFlight: Boolean = false,
    val aiRequestTimedOut: Boolean = false,
    val aiInlineErrorText: String = "",
    val aiInlineActionText: String = "",
    val aiInlineActionType: String = "",
    val aiLastUpdatedLabel: String = "-",
    val aiBreakdownText: String = "-",
    val loading: Boolean = false,
    val statusText: String = "-"
)

class SettingsViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: SettingsState = SettingsState()
        private set
    @Volatile
    private var aiSummaryRequestId: Int = 0

    fun setEmail(value: String) {
        state = state.copy(email = value)
    }

    fun setPassword(value: String) {
        state = state.copy(password = value)
    }

    fun setUserId(value: String) {
        state = state.copy(userId = value)
    }

    fun setAccessToken(value: String) {
        state = state.copy(accessToken = value)
    }

    fun setSelectedPlanId(value: String) {
        state = state.copy(selectedPlanId = value)
    }

    fun setPushAlertsEnabled(value: Boolean) {
        state = state.copy(pushAlertsEnabled = value)
    }

    fun setAlertThreshold(value: String) {
        state = state.copy(alertThreshold = value)
    }

    fun setQuietHoursStart(value: Int) {
        state = state.copy(quietHoursStart = value.coerceIn(0, 23))
    }

    fun setQuietHoursEnd(value: Int) {
        state = state.copy(quietHoursEnd = value.coerceIn(0, 23))
    }

    fun setProfileBasedAlerting(value: Boolean) {
        state = state.copy(profileBasedAlerting = value)
    }

    fun setAiSummaryHours(value: Int) {
        val normalized = if (value <= 24) 24 else 72
        state = state.copy(aiSummaryHours = normalized)
    }

    fun setAiChartMetric(value: String) {
        val metric = when (value) {
            "fallback", "guardrail", "errors", "timeout", "network", "server" -> value
            else -> "total"
        }
        state = state.copy(
            aiChartMetric = metric,
            aiTrendGraphText = buildMetricSparkline(metric)
        )
    }

    fun setAiChartMode(value: String) {
        val mode = if (value == "line") "line" else "bars"
        state = state.copy(aiChartMode = mode)
    }

    fun setDefaultPersona(value: String) {
        state = state.copy(defaultPersona = value)
    }

    fun setPreferredLanguage(value: String) {
        val normalized = if (value.lowercase().startsWith("en")) "en" else "ru"
        state = state.copy(preferredLanguage = normalized)
    }

    @Synchronized
    fun beginAiSummaryRequest(): Int {
        aiSummaryRequestId += 1
        state = state.copy(
            aiRequestInFlight = true,
            aiRequestTimedOut = false,
            aiInlineErrorText = "",
            aiInlineActionText = "",
            aiInlineActionType = ""
        )
        return aiSummaryRequestId
    }

    fun currentAiSummaryRequestId(): Int = aiSummaryRequestId

    fun markAiSummaryTimeout(requestId: Int) {
        if (requestId != currentAiSummaryRequestId()) {
            return
        }
        state = state.copy(
            loading = false,
            aiRequestInFlight = false,
            aiRequestTimedOut = true,
            aiInlineErrorText = l("settings.ai_timeout_inline"),
            aiInlineActionText = l("settings.ai_retry_now"),
            aiInlineActionType = "retry_now"
        )
    }

    private fun classifyAiError(exception: Exception): Triple<String, String, String> {
        return when (exception) {
            is SocketTimeoutException -> Triple(l("settings.ai_timeout_inline"), l("settings.ai_retry_now"), "retry_now")
            is UnknownHostException, is ConnectException, is SocketException -> Triple(l("settings.ai_network_inline"), l("settings.ai_retry_now"), "retry_now")
            is ApiHttpException -> {
                if (exception.statusCode >= 500) {
                    Triple(l("settings.ai_server_inline"), l("settings.ai_retry_later"), "retry_later")
                } else {
                    Triple(l("settings.ai_request_failed_inline"), l("settings.ai_retry_now"), "retry_now")
                }
            }
            else -> Triple(l("settings.ai_request_failed_inline"), l("settings.ai_retry_now"), "retry_now")
        }
    }

    private fun l(key: String): String = AndroidL10n.t(key, state.preferredLanguage)

    private fun buildAsciiSparkline(points: List<Int>): String {
        if (points.isEmpty()) return "-"
        val levels = charArrayOf('.', ':', '-', '=', '+', '*', '#', '%', '@')
        val minValue = points.minOrNull() ?: 0
        val maxValue = points.maxOrNull() ?: 0
        if (maxValue <= minValue) {
            return points.map { '=' }.joinToString("")
        }
        val span = (maxValue - minValue).toDouble()
        return points.joinToString("") { point ->
            val normalized = ((point - minValue) / span * (levels.size - 1)).toInt().coerceIn(0, levels.lastIndex)
            levels[normalized].toString()
        }
    }

    private fun pointsForMetric(metric: String): List<Int> {
        return when (metric) {
            "fallback" -> state.aiTrendFallbackPoints
            "guardrail" -> state.aiTrendGuardrailPoints
            "errors" -> state.aiTrendErrorPoints
            "timeout" -> state.aiTrendTimeoutPoints
            "network" -> state.aiTrendNetworkPoints
            "server" -> state.aiTrendServerPoints
            else -> state.aiTrendPoints
        }
    }

    private fun buildMetricSparkline(metric: String): String {
        val points = pointsForMetric(metric)
        return if (points.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(points)
    }

    private fun hourLabel(raw: String): String {
        val hourPart = raw.substringAfter("T", raw).take(5)
        return if (hourPart.contains(":")) hourPart else raw.take(5)
    }

    fun signup() {
        if (state.email.isBlank() || state.password.length < 8) {
            state = state.copy(statusText = l("settings.valid_credentials_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.signup(state.email, state.password))
            state = state.copy(
                loading = false,
                userId = json.getString("user_id"),
                accessToken = json.getString("access_token"),
                statusText = l("settings.signed_up")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.signup_failed"))
        }
    }

    fun login() {
        if (state.email.isBlank() || state.password.length < 8) {
            state = state.copy(statusText = l("settings.valid_credentials_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.login(state.email, state.password))
            state = state.copy(
                loading = false,
                userId = json.getString("user_id"),
                accessToken = json.getString("access_token"),
                statusText = l("settings.logged_in")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.login_failed"))
        }
    }

    fun loadSettings() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val raw = apiClient.fetchUserSettings(state.userId, state.accessToken)
            val json = JSONObject(raw)
            state = state.copy(
                loading = false,
                pushAlertsEnabled = json.getBoolean("push_alerts_enabled"),
                alertThreshold = json.getString("alert_threshold"),
                defaultPersona = json.getString("default_persona"),
                quietHoursStart = json.optInt("quiet_hours_start", 22),
                quietHoursEnd = json.optInt("quiet_hours_end", 7),
                profileBasedAlerting = json.optBoolean("profile_based_alerting", true),
                preferredLanguage = json.optString("preferred_language", "ru"),
                statusText = l("settings.loaded")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.load_failed"))
        }
    }

    fun saveSettings() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            apiClient.updateUserSettings(
                userId = state.userId,
                pushAlertsEnabled = state.pushAlertsEnabled,
                alertThreshold = state.alertThreshold,
                defaultPersona = state.defaultPersona,
                quietHoursStart = state.quietHoursStart,
                quietHoursEnd = state.quietHoursEnd,
                profileBasedAlerting = state.profileBasedAlerting,
                preferredLanguage = state.preferredLanguage,
                accessToken = state.accessToken
            )
            state = state.copy(loading = false, statusText = l("settings.saved"))
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.save_failed"))
        }
    }

    fun loadSubscriptionPlans() {
        state = state.copy(loading = true)
        try {
            val array = org.json.JSONArray(apiClient.fetchSubscriptionPlans())
            val plans = mutableListOf<Pair<String, String>>()
            for (i in 0 until array.length()) {
                val item = array.getJSONObject(i)
                val planId = item.getString("plan_id")
                val name = item.getString("name")
                plans.add(planId to name)
            }
            val selected = if (plans.any { it.first == state.selectedPlanId }) {
                state.selectedPlanId
            } else {
                plans.firstOrNull()?.first ?: ""
            }
            state = state.copy(
                loading = false,
                subscriptionPlans = plans,
                selectedPlanId = selected,
                statusText = l("settings.plans_loaded")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.plans_load_failed"))
        }
    }

    fun loadSubscriptionStatus() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.fetchMySubscription(state.userId, state.accessToken))
            val planId = if (json.has("plan_id") && !json.isNull("plan_id")) json.getString("plan_id") else state.selectedPlanId
            state = state.copy(
                loading = false,
                selectedPlanId = planId,
                subscriptionStatus = json.getString("status"),
                statusText = l("settings.subscription_loaded")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.subscription_load_failed"))
        }
    }

    fun activateSubscription() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        if (state.selectedPlanId.isBlank()) {
            state = state.copy(statusText = l("settings.select_plan_first"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(
                apiClient.activateSubscription(
                    userId = state.userId,
                    planId = state.selectedPlanId,
                    useTrial = true,
                    accessToken = state.accessToken
                )
            )
            state = state.copy(
                loading = false,
                subscriptionStatus = json.getString("status"),
                statusText = l("settings.subscription_activated")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.subscription_activate_failed"))
        }
    }

    fun cancelSubscription() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.cancelSubscription(state.userId, state.accessToken))
            state = state.copy(
                loading = false,
                subscriptionStatus = json.getString("status"),
                statusText = l("settings.subscription_canceled")
            )
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.subscription_cancel_failed"))
        }
    }

    fun loadAiSummary(requestId: Int? = null) {
        val activeRequestId = requestId ?: beginAiSummaryRequest()
        if (activeRequestId != currentAiSummaryRequestId()) {
            return
        }
        state = state.copy(
            loading = false,
            aiRequestInFlight = false,
            aiRequestTimedOut = false,
            aiSummaryText = l("settings.ai_mobile_unavailable"),
            aiTrendText = "-",
            aiTrendGraphText = "-",
            aiTrendPoints = emptyList(),
            aiTrendFallbackPoints = emptyList(),
            aiTrendGuardrailPoints = emptyList(),
            aiTrendErrorPoints = emptyList(),
            aiTrendTimeoutPoints = emptyList(),
            aiTrendNetworkPoints = emptyList(),
            aiTrendServerPoints = emptyList(),
            aiTrendStartLabel = "-",
            aiTrendEndLabel = "-",
            aiLastUpdatedLabel = "-",
            aiInlineErrorText = "",
            aiInlineActionText = "",
            aiInlineActionType = "",
            aiBreakdownText = "-",
            statusText = l("settings.ai_mobile_unavailable")
        )
    }
}
