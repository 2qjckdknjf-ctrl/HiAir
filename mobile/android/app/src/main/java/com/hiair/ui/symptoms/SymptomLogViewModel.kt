package com.hiair.ui.symptoms

import com.hiair.StoreScreenshotMockSeeder
import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.SymptomFavoritesStore
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
    val usingCachedTaxonomy: Boolean = false,
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
    val expandedCategoryIds: Set<String> = emptySet(),
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

    /** DEBUG-only deterministic demo payload for store screenshot captures. */
    fun seedStoreScreenshotDemo(language: String) {
        if (!com.hiair.BuildConfig.DEBUG) return
        val taxonomy = StoreScreenshotMockSeeder.demoTaxonomy(language)
        state = state.copy(
            profileId = "profile-store-shot",
            taxonomy = taxonomy,
            taxonomyLoading = false,
            taxonomyFailed = false,
            usingCachedTaxonomy = false,
            expandedCategoryIds = setOf(taxonomy.categories.first().id),
            favorites = listOf("cough", "headache"),
            selectedType = taxonomy.categories.first().symptoms.firstOrNull()?.symptomType,
            severity = 3,
        )
    }

    private var favoritesStore: SymptomFavoritesStore? = null
    private var persistedFavoritesLoaded = false

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

    fun attachFavoritesStore(store: SymptomFavoritesStore) {
        favoritesStore = store
        loadPersistedFavorites()
    }

    fun toggleFavorite(symptomType: String) {
        val next = state.favorites.toMutableList()
        val index = next.indexOf(symptomType)
        if (index >= 0) {
            next.removeAt(index)
        } else {
            next.add(symptomType)
        }
        state = state.copy(favorites = next)
        persistFavorites(next)
    }

    private fun loadPersistedFavorites() {
        if (persistedFavoritesLoaded) return
        persistedFavoritesLoaded = true
        val stored = favoritesStore?.load().orEmpty()
        if (stored.isNotEmpty()) {
            state = state.copy(favorites = stored)
        }
    }

    private fun persistFavorites(favorites: List<String>) {
        favoritesStore?.save(favorites)
    }

    private fun resolvedFavorites(available: Set<String>): List<String> {
        loadPersistedFavorites()
        return if (state.favorites.isEmpty()) {
            defaultFavoriteTypes.filter { available.contains(it) }
        } else {
            state.favorites.filter { available.contains(it) }
        }
    }

    fun setSearchText(value: String) {
        state = state.copy(searchText = value)
    }

    fun setSelectedCategory(categoryId: String?) {
        state = state.copy(selectedCategory = categoryId)
    }

    fun toggleCategory(categoryId: String) {
        val next = state.expandedCategoryIds.toMutableSet()
        if (!next.add(categoryId)) {
            next.remove(categoryId)
        }
        state = state.copy(expandedCategoryIds = next)
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
        ProductAnalytics.track(
            "taxonomy_load_started",
            mapOf(
                "endpoint" to "symptoms_taxonomy",
                "profile_present" to if (state.profileId.isBlank()) "no" else "yes",
            ),
        )
        try {
            val json = JSONObject(apiClient.fetchSymptomTaxonomy(language))
            val taxonomy = parseTaxonomy(json)
            if (taxonomy.count <= 0 || taxonomy.categories.isEmpty()) {
                state = state.copy(taxonomyLoading = false, taxonomyFailed = true)
                ProductAnalytics.track(
                    "taxonomy_load_failed",
                    mapOf("endpoint" to "symptoms_taxonomy", "safe_error" to "empty_catalog"),
                )
                return
            }
            val available = taxonomy.categories.flatMap { it.symptoms }.map { it.symptomType }.toSet()
            val favorites = resolvedFavorites(available)
            val expanded = state.expandedCategoryIds.ifEmpty {
                taxonomy.categories.firstOrNull()?.id?.let { setOf(it) }.orEmpty()
            }
            persistTaxonomyCache(json.toString())
            state = state.copy(
                taxonomy = taxonomy,
                taxonomyLoading = false,
                taxonomyFailed = false,
                usingCachedTaxonomy = false,
                favorites = favorites,
                expandedCategoryIds = expanded,
            )
            persistFavorites(favorites)
            ProductAnalytics.track(
                "taxonomy_load_succeeded",
                mapOf(
                    "endpoint" to "symptoms_taxonomy",
                    "returned_count" to taxonomy.count.toString(),
                ),
            )
        } catch (_: Exception) {
            val cached = loadCachedTaxonomy()
            if (cached != null) {
                state = state.copy(
                    taxonomy = cached,
                    taxonomyLoading = false,
                    taxonomyFailed = false,
                    usingCachedTaxonomy = true,
                    expandedCategoryIds = state.expandedCategoryIds.ifEmpty {
                        cached.categories.firstOrNull()?.id?.let { setOf(it) }.orEmpty()
                    },
                )
                ProductAnalytics.track(
                    "taxonomy_load_failed",
                    mapOf("endpoint" to "symptoms_taxonomy", "safe_error" to "network_using_cache"),
                )
            } else {
                state = state.copy(
                    taxonomy = null,
                    taxonomyLoading = false,
                    taxonomyFailed = true,
                    usingCachedTaxonomy = false,
                )
                ProductAnalytics.track(
                    "taxonomy_load_failed",
                    mapOf("endpoint" to "symptoms_taxonomy", "safe_error" to "decode_or_network"),
                )
            }
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
                    category.label.lowercase().contains(query)
            }
            if (symptoms.isEmpty()) null else category.copy(symptoms = symptoms)
        }
    }

    fun labelFor(symptomType: String): String {
        for (category in state.taxonomy?.categories.orEmpty()) {
            val item = category.symptoms.firstOrNull { it.symptomType == symptomType }
            if (item != null) return item.label
        }
        return l("symptoms.unknown", "en")
    }

    private fun persistTaxonomyCache(rawJson: String) {
        memoryTaxonomyCache = rawJson
    }

    private fun loadCachedTaxonomy(): SymptomTaxonomy? {
        val raw = memoryTaxonomyCache ?: return null
        return try {
            parseTaxonomy(JSONObject(raw))
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        @Volatile
        private var memoryTaxonomyCache: String? = null
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
            val requestId = java.util.UUID.randomUUID().toString()
            payload.put("clientRequestId", requestId)
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
        val notice = json.optString("safetyNotice")
            .ifBlank { json.optString("severityNotice") }
        return SymptomTaxonomy(
            safetyNotice = notice,
            categories = categories,
            count = json.optInt("count", categories.sumOf { it.symptoms.size }),
        )
    }

    private fun l(key: String, preferredLanguage: String): String =
        AndroidL10n.t(key, preferredLanguage)
}
