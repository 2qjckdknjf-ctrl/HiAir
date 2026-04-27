package com.hiair.ui.symptoms

import com.hiair.models.SymptomInput
import com.hiair.models.SymptomLogRequest
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.i18n.AndroidL10n
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

    fun submit(userId: String, accessToken: String?, language: String = "ru") {
        if (state.profileId.isBlank()) {
            state = state.copy(statusText = AndroidL10n.t("planner.profile_required", language))
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
                statusText = "${AndroidL10n.t("symptoms.saved_at", language)} ${json.getString("timestamp_utc")}"
            )
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                statusText = AndroidL10n.t("symptoms.save_failed", language)
            )
        }
    }

    fun quickLog(userId: String, accessToken: String?, symptomType: String, language: String = "ru") {
        if (state.profileId.isBlank()) {
            state = state.copy(statusText = AndroidL10n.t("planner.profile_required", language))
            return
        }
        state = state.copy(loading = true)
        try {
            apiClient.createQuickSymptom(
                userId = userId,
                accessToken = accessToken,
                profileId = state.profileId,
                symptomType = symptomType,
                intensity = state.quickIntensity
            )
            state = state.copy(loading = false, statusText = AndroidL10n.t("symptoms.quick_saved", language))
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = AndroidL10n.t("symptoms.quick_failed", language))
        }
    }
}
