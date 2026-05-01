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
    val morningBriefingEnabled: Boolean = false,
    val morningBriefingTime: String = "07:30",
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

    fun setMorningBriefingEnabled(value: Boolean) {
        state = state.copy(morningBriefingEnabled = value)
    }

    fun setMorningBriefingTime(value: String) {
        state = state.copy(morningBriefingTime = value)
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
            val briefing = JSONObject(apiClient.fetchBriefingSchedule(state.userId, state.accessToken))
            state = state.copy(
                loading = false,
                pushAlertsEnabled = json.getBoolean("push_alerts_enabled"),
                alertThreshold = json.getString("alert_threshold"),
                defaultPersona = json.getString("default_persona"),
                quietHoursStart = json.optInt("quiet_hours_start", 22),
                quietHoursEnd = json.optInt("quiet_hours_end", 7),
                morningBriefingEnabled = briefing.optBoolean("enabled", false),
                morningBriefingTime = briefing.optString("local_time", "07:30"),
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
            apiClient.updateBriefingSchedule(
                userId = state.userId,
                accessToken = state.accessToken,
                localTime = state.morningBriefingTime,
                enabled = state.morningBriefingEnabled
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
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.fetchAiSummaryDetailed(hours = state.aiSummaryHours))
            val summary = json.getJSONObject("summary")
            val trend = json.getJSONArray("trend")
            val breakdown = json.getJSONObject("breakdown")
            val byPromptVersion = breakdown.getJSONArray("by_prompt_version")
            val byModelName = breakdown.getJSONArray("by_model_name")
            val byErrorType = breakdown.optJSONArray("by_error_type")
            val fallbackRate = summary.optDouble("fallback_rate_pct", 0.0)
            val guardrailRate = summary.optDouble("guardrail_block_rate_pct", 0.0)
            val timeoutCount = summary.optInt("timeout_count", 0)
            val networkCount = summary.optInt("network_count", 0)
            val serverCount = summary.optInt("server_count", 0)
            val trendText = if (trend.length() > 0) {
                val last = trend.getJSONObject(trend.length() - 1)
                "${l("settings.ai_latest_hour")} ${last.optString("hour")}: total ${last.optInt("total", 0)}, fallback ${last.optInt("fallback_count", 0)}, blocks ${last.optInt("guardrail_block_count", 0)}"
            } else {
                l("settings.ai_no_trend")
            }
            val trendStartLabel = if (trend.length() > 0) hourLabel(trend.getJSONObject(0).optString("hour")) else "-"
            val trendEndLabel = if (trend.length() > 0) hourLabel(trend.getJSONObject(trend.length() - 1).optString("hour")) else "-"
            val trendPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("total", 0))
                }
            }
            val fallbackPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("fallback_count", 0))
                }
            }
            val guardrailPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("guardrail_block_count", 0))
                }
            }
            val timeoutPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("timeout_count", 0))
                }
            }
            val networkPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("network_count", 0))
                }
            }
            val serverPoints = buildList {
                for (i in 0 until trend.length()) {
                    add(trend.getJSONObject(i).optInt("server_count", 0))
                }
            }
            val errorPoints = buildList {
                for (i in timeoutPoints.indices) {
                    add(timeoutPoints[i] + networkPoints.getOrElse(i) { 0 } + serverPoints.getOrElse(i) { 0 })
                }
            }
            val selectedMetric = state.aiChartMetric
            val trendGraphText = when (selectedMetric) {
                "fallback" -> if (fallbackPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(fallbackPoints)
                "guardrail" -> if (guardrailPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(guardrailPoints)
                "errors" -> if (errorPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(errorPoints)
                "timeout" -> if (timeoutPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(timeoutPoints)
                "network" -> if (networkPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(networkPoints)
                "server" -> if (serverPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(serverPoints)
                else -> if (trendPoints.isEmpty()) l("settings.ai_no_trend") else buildAsciiSparkline(trendPoints)
            }
            val topPrompt = if (byPromptVersion.length() > 0) {
                val item = byPromptVersion.getJSONObject(0)
                "${l("settings.ai_top_prompt")}: ${item.optString("prompt_version")} (total ${item.optInt("total", 0)})"
            } else {
                l("settings.ai_no_prompt_breakdown")
            }
            val topModel = if (byModelName.length() > 0) {
                val item = byModelName.getJSONObject(0)
                "${l("settings.ai_top_model")}: ${item.optString("model_name")} (total ${item.optInt("total", 0)})"
            } else {
                l("settings.ai_no_model_breakdown")
            }
            val errorBreakdown = if (byErrorType != null && byErrorType.length() > 0) {
                buildList {
                    for (i in 0 until byErrorType.length()) {
                        val item = byErrorType.getJSONObject(i)
                        val kind = item.optString("error_type", "other")
                        val count = item.optInt("total", 0)
                        if (count > 0) {
                            val key = when (kind) {
                                "timeout", "network", "server", "other" -> "settings.ai_error_type.$kind"
                                else -> "settings.ai_error_type.other"
                            }
                            add("${l(key)} $count")
                        }
                    }
                }.joinToString(", ").ifBlank { "-" }
            } else {
                "-"
            }
            val errorSummary = "${l("settings.ai_error_counts")}: t:$timeoutCount, n:$networkCount, s:$serverCount"
            if (activeRequestId != currentAiSummaryRequestId()) {
                return
            }
            state = state.copy(
                loading = false,
                aiRequestInFlight = false,
                aiRequestTimedOut = false,
                aiInlineErrorText = "",
                aiInlineActionText = "",
                aiInlineActionType = "",
                aiLastUpdatedLabel = trendEndLabel,
                aiSummaryText = "${state.aiSummaryHours}h ${l("settings.ai_events")}: ${summary.optInt("total", 0)}, ${l("settings.ai_fallback")}: ${summary.optInt("fallback_count", 0)} (${String.format("%.1f", fallbackRate)}%), ${l("settings.ai_guardrail_blocks")}: ${summary.optInt("guardrail_block_count", 0)} (${String.format("%.1f", guardrailRate)}%)",
                aiTrendText = trendText,
                aiTrendGraphText = trendGraphText,
                aiTrendPoints = trendPoints,
                aiTrendFallbackPoints = fallbackPoints,
                aiTrendGuardrailPoints = guardrailPoints,
                aiTrendErrorPoints = errorPoints,
                aiTrendTimeoutPoints = timeoutPoints,
                aiTrendNetworkPoints = networkPoints,
                aiTrendServerPoints = serverPoints,
                aiTrendStartLabel = trendStartLabel,
                aiTrendEndLabel = trendEndLabel,
                aiBreakdownText = "$topPrompt\n$topModel\n$errorSummary\n${l("settings.ai_error_counts")}: $errorBreakdown",
                statusText = l("settings.ai_loaded")
            )
        } catch (ex: Exception) {
            if (activeRequestId != currentAiSummaryRequestId()) {
                return
            }
            if (state.aiRequestTimedOut) {
                return
            }
            val (inlineErrorText, inlineActionText, inlineActionType) = classifyAiError(ex)
            state = state.copy(
                loading = false,
                aiRequestInFlight = false,
                aiRequestTimedOut = false,
                aiSummaryText = l("settings.ai_load_failed_inline"),
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
                aiInlineErrorText = inlineErrorText,
                aiInlineActionText = inlineActionText,
                aiInlineActionType = inlineActionType,
                aiBreakdownText = "-",
                statusText = l("settings.ai_failed")
            )
        }
    }
}
