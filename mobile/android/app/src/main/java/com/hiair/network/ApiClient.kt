package com.hiair.network

import com.hiair.models.RiskEstimateRequest
import com.hiair.models.SymptomLogRequest
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class ApiHttpException(val statusCode: Int, message: String) : RuntimeException(message)

class ApiClient(private val baseUrl: String) {
    data class AuthState(
        val userId: String,
        val accessToken: String,
        val refreshToken: String
    )

    companion object {
        @Volatile
        private var authProvider: (() -> AuthState?)? = null
        @Volatile
        private var authUpdater: ((AuthState?) -> Unit)? = null

        fun configureAuth(
            provider: (() -> AuthState?)?,
            updater: ((AuthState?) -> Unit)?
        ) {
            authProvider = provider
            authUpdater = updater
        }

        private fun currentAuthState(): AuthState? = authProvider?.invoke()

        private fun updateAuthState(state: AuthState?) {
            authUpdater?.invoke(state)
        }
    }

    @Suppress("UNUSED_PARAMETER")
    private fun authHeaders(userId: String, accessToken: String?): Map<String, String> {
        if (!accessToken.isNullOrBlank()) {
            return mapOf("Authorization" to "Bearer $accessToken")
        }
        return emptyMap()
    }

    fun signup(email: String, password: String): String {
        val endpoint = "$baseUrl/api/auth/signup"
        val json = JSONObject().apply {
            put("email", email)
            put("password", password)
        }.toString()
        return request("POST", endpoint, json)
    }

    fun login(email: String, password: String): String {
        val endpoint = "$baseUrl/api/auth/login"
        val json = JSONObject().apply {
            put("email", email)
            put("password", password)
        }.toString()
        return request("POST", endpoint, json)
    }

    fun fetchDailyPlanner(
        persona: String = "adult",
        lat: Double = 41.39,
        lon: Double = 2.17,
        hours: Int = 12
    ): String {
        val endpoint = "$baseUrl/api/planner/daily?persona=$persona&lat=$lat&lon=$lon&hours=$hours"
        return request("GET", endpoint, null)
    }

    fun fetchDashboardOverview(
        userId: String,
        accessToken: String? = null,
        profileId: String? = null,
        persona: String = "adult",
        lat: Double = 41.39,
        lon: Double = 2.17
    ): String {
        val profileQuery = if (profileId != null) "&profile_id=$profileId" else ""
        val endpoint = "$baseUrl/api/dashboard/overview?persona=$persona&lat=$lat&lon=$lon$profileQuery"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun fetchCurrentRisk(
        userId: String,
        accessToken: String? = null,
        profileId: String
    ): String {
        val endpoint = "$baseUrl/api/air/current-risk?profileId=$profileId"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun fetchAirDayPlan(
        userId: String,
        accessToken: String? = null,
        profileId: String
    ): String {
        val endpoint = "$baseUrl/api/air/day-plan?profileId=$profileId"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun fetchPersonalPatterns(
        userId: String,
        accessToken: String? = null,
        profileId: String,
        windowDays: Int = 30,
        language: String = "ru"
    ): String {
        val endpoint = "$baseUrl/api/insights/personal-patterns?profile_id=$profileId&window_days=$windowDays&language=$language"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun fetchBriefingSchedule(
        userId: String,
        accessToken: String? = null
    ): String {
        val endpoint = "$baseUrl/api/briefings/schedule"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun updateBriefingSchedule(
        userId: String,
        accessToken: String? = null,
        localTime: String,
        enabled: Boolean
    ): String {
        val endpoint = "$baseUrl/api/briefings/schedule"
        val json = JSONObject().apply {
            put("local_time", localTime)
            put("enabled", enabled)
        }.toString()
        return request("PUT", endpoint, json, authHeaders(userId, accessToken))
    }

    fun fetchEnvironmentSnapshotMock(lat: Double, lon: Double): String {
        val endpoint = "$baseUrl/api/environment/snapshot?lat=$lat&lon=$lon&source=mock"
        return request("GET", endpoint, null)
    }

    fun estimateRisk(payload: RiskEstimateRequest): String {
        val endpoint = "$baseUrl/api/risk/estimate"
        val json = JSONObject().apply {
            put("persona", payload.persona)
            put("profile_id", payload.profile_id)
            put(
                "symptoms",
                JSONObject().apply {
                    put("cough", payload.symptoms.cough)
                    put("wheeze", payload.symptoms.wheeze)
                    put("headache", payload.symptoms.headache)
                    put("fatigue", payload.symptoms.fatigue)
                    put("sleep_quality", payload.symptoms.sleep_quality)
                }
            )
            put(
                "environment",
                JSONObject().apply {
                    put("temperature_c", payload.environment.temperature_c)
                    put("humidity_percent", payload.environment.humidity_percent)
                    put("aqi", payload.environment.aqi)
                    put("pm25", payload.environment.pm25)
                    put("ozone", payload.environment.ozone)
                    put("source", payload.environment.source)
                }
            )
        }.toString()
        return request("POST", endpoint, json)
    }

    fun logSymptom(
        userId: String,
        accessToken: String? = null,
        payload: SymptomLogRequest
    ): String {
        val endpoint = "$baseUrl/api/symptoms/log"
        val json = JSONObject().apply {
            put("profile_id", payload.profile_id)
            put(
                "symptom",
                JSONObject().apply {
                    put("cough", payload.symptom.cough)
                    put("wheeze", payload.symptom.wheeze)
                    put("headache", payload.symptom.headache)
                    put("fatigue", payload.symptom.fatigue)
                    put("sleep_quality", payload.symptom.sleep_quality)
                }
            )
        }.toString()
        return request("POST", endpoint, json, authHeaders(userId, accessToken))
    }

    fun fetchUserSettings(userId: String, accessToken: String? = null): String {
        val endpoint = "$baseUrl/api/settings"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun updateUserSettings(
        userId: String,
        pushAlertsEnabled: Boolean,
        alertThreshold: String,
        defaultPersona: String,
        quietHoursStart: Int,
        quietHoursEnd: Int,
        profileBasedAlerting: Boolean,
        preferredLanguage: String,
        accessToken: String? = null
    ): String {
        val endpoint = "$baseUrl/api/settings"
        val json = JSONObject().apply {
            put("push_alerts_enabled", pushAlertsEnabled)
            put("alert_threshold", alertThreshold)
            put("default_persona", defaultPersona)
            put("quiet_hours_start", quietHoursStart)
            put("quiet_hours_end", quietHoursEnd)
            put("profile_based_alerting", profileBasedAlerting)
            put("preferred_language", preferredLanguage)
        }.toString()
        return request("PUT", endpoint, json, authHeaders(userId, accessToken))
    }

    fun createQuickSymptom(
        userId: String,
        accessToken: String? = null,
        profileId: String,
        symptomType: String,
        intensity: Int
    ): String {
        val endpoint = "$baseUrl/api/symptoms"
        val json = JSONObject().apply {
            put("profileId", profileId)
            put("symptomType", symptomType)
            put("intensity", intensity)
            put("note", JSONObject.NULL)
        }.toString()
        return request("POST", endpoint, json, authHeaders(userId, accessToken))
    }

    fun fetchAiSummary(hours: Int = 24): String {
        val endpoint = "$baseUrl/api/observability/ai-summary?hours=$hours"
        return request("GET", endpoint, null)
    }

    fun fetchAiSummaryDetailed(hours: Int = 24): String {
        val endpoint = "$baseUrl/api/observability/ai-summary-detailed?hours=$hours"
        return requestStrict("GET", endpoint, null)
    }

    fun registerDeviceToken(
        userId: String,
        platform: String,
        deviceToken: String,
        profileId: String? = null,
        accessToken: String? = null
    ): String {
        val endpoint = "$baseUrl/api/notifications/device-token"
        val json = JSONObject().apply {
            put("platform", platform)
            put("device_token", deviceToken)
            put("profile_id", profileId)
        }.toString()
        return request("POST", endpoint, json, authHeaders(userId, accessToken))
    }

    fun fetchSubscriptionPlans(): String {
        val endpoint = "$baseUrl/api/subscriptions/plans"
        return request("GET", endpoint, null)
    }

    fun fetchMySubscription(userId: String, accessToken: String? = null): String {
        val endpoint = "$baseUrl/api/subscriptions/me"
        return request("GET", endpoint, null, authHeaders(userId, accessToken))
    }

    fun activateSubscription(
        userId: String,
        planId: String,
        useTrial: Boolean = true,
        accessToken: String? = null
    ): String {
        val endpoint = "$baseUrl/api/subscriptions/activate"
        val json = JSONObject().apply {
            put("plan_id", planId)
            put("use_trial", useTrial)
        }.toString()
        return request("POST", endpoint, json, authHeaders(userId, accessToken))
    }

    fun cancelSubscription(userId: String, accessToken: String? = null): String {
        val endpoint = "$baseUrl/api/subscriptions/cancel"
        return request("POST", endpoint, "{}", authHeaders(userId, accessToken))
    }

    private fun request(
        method: String,
        endpoint: String,
        body: String?,
        headers: Map<String, String> = emptyMap()
    ): String {
        val (_, payload) = executeRequest(
            method = method,
            endpoint = endpoint,
            body = body,
            headers = headers,
            allowRefresh = true
        )
        return payload
    }

    private fun requestStrict(
        method: String,
        endpoint: String,
        body: String?,
        headers: Map<String, String> = emptyMap()
    ): String {
        val (code, payload) = executeRequest(
            method = method,
            endpoint = endpoint,
            body = body,
            headers = headers,
            allowRefresh = true
        )
        if (code !in 200..299) {
            throw ApiHttpException(code, "HTTP $code for $endpoint")
        }
        return payload
    }

    private fun executeRequest(
        method: String,
        endpoint: String,
        body: String?,
        headers: Map<String, String>,
        allowRefresh: Boolean
    ): Pair<Int, String> {
        val connection = URL(endpoint).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        headers.forEach { (name, value) -> connection.setRequestProperty(name, value) }
        if (method == "POST" || method == "PUT") {
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            if (body != null) {
                connection.outputStream.use { output ->
                    output.write(body.toByteArray())
                }
            }
        }
        val code: Int
        val payload: String
        try {
            code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            payload = stream?.bufferedReader()?.readText() ?: ""
        } finally {
            connection.disconnect()
        }

        if (allowRefresh && code == 401 && headers.containsKey("Authorization") && refreshAccessToken()) {
            val refreshedHeaders = headers.toMutableMap()
            val refreshedToken = currentAuthState()?.accessToken.orEmpty()
            if (refreshedToken.isNotBlank()) {
                refreshedHeaders["Authorization"] = "Bearer $refreshedToken"
            }
            return executeRequest(
                method = method,
                endpoint = endpoint,
                body = body,
                headers = refreshedHeaders,
                allowRefresh = false
            )
        }
        return code to payload
    }

    private fun refreshAccessToken(): Boolean {
        val state = currentAuthState() ?: return false
        if (state.refreshToken.isBlank()) {
            updateAuthState(null)
            return false
        }
        return try {
            val endpoint = "$baseUrl/api/auth/refresh"
            val body = JSONObject().apply {
                put("refresh_token", state.refreshToken)
            }.toString()
            val (code, payload) = executeRequest(
                method = "POST",
                endpoint = endpoint,
                body = body,
                headers = emptyMap(),
                allowRefresh = false
            )
            if (code !in 200..299) {
                updateAuthState(null)
                return false
            }
            val json = JSONObject(payload)
            val nextState = AuthState(
                userId = json.optString("user_id", state.userId),
                accessToken = json.getString("access_token"),
                refreshToken = json.optString("refresh_token", state.refreshToken)
            )
            updateAuthState(nextState)
            true
        } catch (_: Exception) {
            updateAuthState(null)
            false
        }
    }
}
