package com.hiair.ui.symptoms

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.i18n.AndroidL10n
import org.json.JSONArray
import org.json.JSONObject
import java.util.TimeZone

data class SymptomItem(
    val symptomType: String,
    val label: String,
    val redFlag: Boolean,
)

data class SymptomCategory(
    val id: String,
    val label: String,
    val symptoms: List<SymptomItem>,
)

data class SymptomTaxonomy(
    val safetyNotice: String,
    val categories: List<SymptomCategory>,
    val count: Int,
)

data class SymptomLogState(
    val profileId: String = "",
    val taxonomy: SymptomTaxonomy? = null,
    val taxonomyLoading: Boolean = false,
    val taxonomyFailed: Boolean = false,
    val selectedType: String? = null,
    val severity: Int = 2,
    val locationContext: String = "unspecified",
    val frequency: String = "unspecified",
    val durationMinutes: Int = 0,
    val ongoing: Boolean = false,
    val activityAtOnset: String = "unspecified",
    val hydrationState: String = "unspecified",
    val medicationTaken: Boolean = false,
    val suspectedTrigger: String = "",
    val note: String = "",
    val searchText: String = "",
    val selectedCategory: String? = null,
    val favorites: List<String> = emptyList(),
    val loading: Boolean = false,
    val statusText: String = "",
    val safetyNotice: String? = null,
)

class SymptomLogViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl),
) {
    var state: SymptomLogState = SymptomLogState()
        private set

    private val defaultFavoriteTypes = listOf(
        "cough",
        "headache",
        "fatigue",
        "itchy_eyes",
        "shortness_of_breath",
    )

    fun updateProfileId(value: String) {
        state = state.copy(profileId = value)
    }

    fun setSearchText(value: String) {
        state = state.copy(searchText = value)
    }

    fun setSelectedCategory(categoryId: String?) {
        state = state.copy(selectedCategory = categoryId)
    }

    fun selectSymptom(symptomType: String, redFlag: Boolean) {
        state = state.copy(
            selectedType = symptomType,
            safetyNotice = if (redFlag) state.taxonomy?.safetyNotice else state.safetyNotice,
        )
    }

    fun setSeverity(value: Int) {
        state = state.copy(severity = value.coerceIn(1, 5))
    }

    fun setLocationContext(value: String) {
        state = state.copy(locationContext = value)
    }

    fun setFrequency(value: String) {
        state = state.copy(frequency = value)
    }

    fun setDurationMinutes(value: Int) {
        state = state.copy(durationMinutes = value)
    }

    fun setOngoing(value: Boolean) {
        state = state.copy(ongoing = value)
    }

    fun setActivityAtOnset(value: String) {
        state = state.copy(activityAtOnset = value)
    }

    fun setHydrationState(value: String) {
        state = state.copy(hydrationState = value)
    }

    fun setMedicationTaken(value: Boolean) {
        state = state.copy(medicationTaken = value)
    }

    fun setSuspectedTrigger(value: String) {
        state = state.copy(suspectedTrigger = value)
    }

    fun setNote(value: String) {
        state = state.copy(note = value)
    }

    fun loadTaxonomy(language: String) {
        state = state.copy(taxonomyLoading = true, taxonomyFailed = false)
        try {
            val json = JSONObject(apiClient.fetchSymptomTaxonomy(language))
            val taxonomy = parseTaxonomy(json)
            val available = taxonomy.categories.flatMap { it.symptoms }.map { it.symptomType }.toSet()
            val favorites = if (state.favorites.isEmpty()) {
                defaultFavoriteTypes.filter { available.contains(it) }
            } else {
                state.favorites.filter { available.contains(it) }
            }
            state = state.copy(
                taxonomy = taxonomy,
                taxonomyLoading = false,
                taxonomyFailed = false,
                favorites = favorites,
            )
        } catch (_: Exception) {
            state = state.copy(
                taxonomy = null,
                taxonomyLoading = false,
                taxonomyFailed = true,
            )
        }
    }

    fun filteredCategories(): List<SymptomCategory> {
        val taxonomy = state.taxonomy ?: return emptyList()
        val query = state.searchText.trim().lowercase()
        return taxonomy.categories.mapNotNull { category ->
            if (state.selectedCategory != null && state.selectedCategory != category.id) {
                return@mapNotNull null
            }
            val symptoms = category.symptoms.filter { item ->
                query.isEmpty() ||
                    item.label.lowercase().contains(query) ||
                    item.symptomType.contains(query)
            }
            if (symptoms.isEmpty()) null else category.copy(symptoms = symptoms)
        }
    }

    fun labelFor(symptomType: String): String {
        for (category in state.taxonomy?.categories.orEmpty()) {
            val item = category.symptoms.firstOrNull { it.symptomType == symptomType }
            if (item != null) return item.label
        }
        return symptomType
    }

    fun submit(userId: String, accessToken: String?, preferredLanguage: String) {
        val selectedType = state.selectedType
        if (selectedType.isNullOrBlank()) {
            state = state.copy(statusText = l("symptoms.select_first", preferredLanguage))
            return
        }
        if (state.profileId.isBlank()) {
            state = state.copy(statusText = l("symptoms.profile_required", preferredLanguage))
            return
        }
        state = state.copy(loading = true, statusText = "")
        try {
            val payload = JSONObject()
                .put("profileId", state.profileId)
                .put("symptomType", selectedType)
                .put("severity", state.severity)
                .put("ongoing", state.ongoing)
                .put("timezone", TimeZone.getDefault().id)
            if (state.durationMinutes > 0) {
                payload.put("durationMinutes", state.durationMinutes)
            }
            if (state.frequency != "unspecified") {
                payload.put("frequency", state.frequency)
            }
            if (state.activityAtOnset != "unspecified") {
                payload.put("activityAtOnset", state.activityAtOnset)
            }
            if (state.locationContext != "unspecified") {
                payload.put("locationContext", state.locationContext)
            }
            if (state.hydrationState != "unspecified") {
                payload.put("hydrationState", state.hydrationState)
            }
            if (state.medicationTaken) {
                payload.put("medicationTaken", true)
            }
            val trigger = state.suspectedTrigger.trim()
            if (trigger.isNotBlank()) {
                payload.put("suspectedTrigger", trigger)
            }
            if (state.note.isNotBlank()) {
                payload.put("note", state.note)
            }
            val response = apiClient.createComprehensiveSymptom(
                userId = userId,
                accessToken = accessToken,
                body = payload.toString(),
                language = preferredLanguage,
            )
            val json = JSONObject(response)
            val notice = json.optString("safetyNotice").ifBlank { null }
            state = state.copy(
                loading = false,
                statusText = l("symptoms.quick_saved", preferredLanguage),
                safetyNotice = notice ?: state.safetyNotice,
                note = "",
                suspectedTrigger = "",
            )
            ProductAnalytics.track("symptom_logged", mapOf("mode" to "comprehensive"))
        } catch (_: Exception) {
            state = state.copy(
                loading = false,
                statusText = l("symptoms.save_failed", preferredLanguage),
            )
        }
    }

    fun quickLog(
        userId: String,
        accessToken: String?,
        symptomType: String,
        preferredLanguage: String,
    ) {
        val redFlag = state.taxonomy?.categories
            ?.flatMap { it.symptoms }
            ?.firstOrNull { it.symptomType == symptomType }
            ?.redFlag == true
        selectSymptom(symptomType, redFlag)
        submit(userId, accessToken, preferredLanguage)
    }

    private fun parseTaxonomy(json: JSONObject): SymptomTaxonomy {
        val categories = mutableListOf<SymptomCategory>()
        val categoryArray = json.optJSONArray("categories") ?: JSONArray()
        for (i in 0 until categoryArray.length()) {
            val categoryJson = categoryArray.getJSONObject(i)
            val symptoms = mutableListOf<SymptomItem>()
            val symptomArray = categoryJson.optJSONArray("symptoms") ?: JSONArray()
            for (j in 0 until symptomArray.length()) {
                val symptomJson = symptomArray.getJSONObject(j)
                symptoms.add(
                    SymptomItem(
                        symptomType = symptomJson.getString("symptomType"),
                        label = symptomJson.getString("label"),
                        redFlag = symptomJson.optBoolean("redFlag", false),
                    ),
                )
            }
            categories.add(
                SymptomCategory(
                    id = categoryJson.getString("id"),
                    label = categoryJson.getString("label"),
                    symptoms = symptoms,
                ),
            )
        }
        val notice = json.optString("severityNotice")
            .ifBlank { json.optString("safetyNotice") }
        return SymptomTaxonomy(
            safetyNotice = notice,
            categories = categories,
            count = json.optInt("count", categories.sumOf { it.symptoms.size }),
        )
    }

    private fun l(key: String, preferredLanguage: String): String =
        AndroidL10n.t(key, preferredLanguage)
}
