package com.hiair.ui.symptoms

import com.hiair.analytics.ProductAnalytics
import com.hiair.models.SymptomInput
import com.hiair.models.SymptomLogRequest
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import org.json.JSONObject

data class SymptomLogState(
    val profileId: String = "",
    val cough: Boolean = false,
    val wheeze: Boolean = false,
    val headache: Boolean = false,
    val fatigue: Boolean = false,
    val sleepQuality: Int = 3,
    val quickIntensity: Int = 2,
    val loading: Boolean = false,
    val statusText: String = "-"
)

class SymptomLogViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: SymptomLogState = SymptomLogState()
        private set

    fun updateProfileId(value: String) {
        state = state.copy(profileId = value)
    }

    fun updateToggles(
        cough: Boolean = state.cough,
        wheeze: Boolean = state.wheeze,
        headache: Boolean = state.headache,
        fatigue: Boolean = state.fatigue,
        sleepQuality: Int = state.sleepQuality
    ) {
        state = state.copy(
            cough = cough,
            wheeze = wheeze,
            headache = headache,
            fatigue = fatigue,
            sleepQuality = sleepQuality
        )
    }

    fun setQuickIntensity(value: Int) {
        state = state.copy(quickIntensity = value.coerceIn(1, 5))
    }

    fun submit(userId: String, accessToken: String?) {
        if (state.profileId.isBlank()) {
            state = state.copy(statusText = "Profile ID is required.")
            return
        }
        state = state.copy(loading = true)
        try {
            val response = apiClient.logSymptom(
                userId = userId,
                accessToken = accessToken,
                payload = SymptomLogRequest(
                    profile_id = state.profileId,
                    symptom = SymptomInput(
                        cough = state.cough,
                        wheeze = state.wheeze,
                        headache = state.headache,
                        fatigue = state.fatigue,
                        sleep_quality = state.sleepQuality
                    )
                )
            )
            val json = JSONObject(response)
            state = state.copy(
                loading = false,
                statusText = "Saved at ${json.getString("timestamp_utc")}"
            )
            ProductAnalytics.track("symptom_logged", mapOf("mode" to "form"))
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                statusText = "Failed to save symptoms."
            )
        }
    }

    fun quickLog(userId: String, accessToken: String?, symptomType: String) {
        if (state.profileId.isBlank()) {
            state = state.copy(statusText = "Profile ID is required.")
            return
        }
        state = state.copy(loading = true)
        try {
            val payload = JSONObject()
                .put("profileId", state.profileId)
                .put("symptomType", symptomType)
                .put("severity", state.quickIntensity)
                .put("ongoing", false)
                .put("timezone", java.util.TimeZone.getDefault().id)
            val response = apiClient.createComprehensiveSymptom(
                userId = userId,
                accessToken = accessToken,
                body = payload.toString(),
            )
            val json = JSONObject(response)
            val notice = json.optString("safetyNotice").ifBlank { null }
            state = state.copy(
                loading = false,
                statusText = if (notice != null) "Saved. $notice" else "Quick symptom saved.",
            )
            ProductAnalytics.track("symptom_logged", mapOf("mode" to "comprehensive"))
        } catch (_: Exception) {
            // Fallback to legacy quick endpoint for older backends.
            try {
                apiClient.createQuickSymptom(
                    userId = userId,
                    accessToken = accessToken,
                    profileId = state.profileId,
                    symptomType = symptomType,
                    intensity = state.quickIntensity
                )
                state = state.copy(loading = false, statusText = "Quick symptom saved.")
                ProductAnalytics.track("symptom_logged", mapOf("mode" to "quick"))
            } catch (_: Exception) {
                state = state.copy(loading = false, statusText = "Failed to save quick symptom.")
            }
        }
    }

    fun loadTaxonomy(language: String = "ru"): org.json.JSONObject? {
        return try {
            JSONObject(apiClient.fetchSymptomTaxonomy(language))
        } catch (_: Exception) {
            null
        }
    }
}
