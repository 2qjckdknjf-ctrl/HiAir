package com.hiair.ui.planner

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.settings.SavedPlaceItem
import com.hiair.ui.settings.SettingsViewModel
import com.hiair.ui.i18n.AndroidL10n
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.concurrent.atomic.AtomicLong
import java.util.Calendar
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

private const val DEFAULT_ACTIVITY_ID = "walking"
private val ACTION_DURATION_OPTIONS = listOf(15, 30, 45, 60, 90, 120)
private val ACTION_INTENSITY_OPTIONS = listOf("low", "moderate", "high")

data class ActivityCatalogEntry(
    val id: String,
    val defaultDurationMinutes: Int,
    val defaultIntensity: String,
    val outdoor: Boolean = true,
)

data class ActivityWindowLine(
    val tier: String,
    val line: String,
)

data class PlannerState(
    val loading: Boolean = false,
    val statusText: String = "-",
    val freshnessText: String = "",
    val safeWindows: List<String> = emptyList(),
    val ventilationWindows: List<String> = emptyList(),
    val hourly: List<String> = emptyList(),
    val hourlyRiskLevels: List<String> = emptyList(),
    val currentRiskLevel: String = "",
    val currentRiskScore: Int = 0,
    val peakLine: String = "",
    val premiumRequired: Boolean = false,
    val forecastAvailable: Boolean = true,
    val dataQuality: String = "",
    val freshness: String = "",
    val missingMetrics: List<String> = emptyList(),
    val sources: List<String> = emptyList(),
    val activityCatalog: List<ActivityCatalogEntry> = emptyList(),
    val selectedActivityId: String = DEFAULT_ACTIVITY_ID,
    val selectedDurationMinutes: Int = 30,
    val selectedIntensity: String = "low",
    val selectedPlaceId: String = "",
    val savedPlaces: List<SavedPlaceItem> = emptyList(),
    val activityPlanMarked: Boolean = false,
    val activityPlanMarkStatus: String = "",
    val ventilationWindowMarked: Boolean = false,
    val ventilationMarkStatus: String = "",
    val activityPlanLoading: Boolean = false,
    val activityPlanStatusText: String = "",
    val activityWindows: List<ActivityWindowLine> = emptyList(),
    val activityRecommendedStart: String = "",
    val activityRecommendedStartRaw: String = "",
    val earliestStartOverride: String = "",
    val selectedTimePreference: ActionTimePreference = ActionTimePreference.ANY,
    val activityTimezone: String = "",
    val activityTimezonePlaceId: String = "",
    val activityPlanningAccess: String = "full",
    val activityPremiumRequired: Boolean = false,
    val activityForecastAvailable: Boolean = true,
)

class DailyPlannerViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    private val activityRequestGeneration = AtomicLong()

    fun reset() {
        activityRequestGeneration.incrementAndGet()
        hasAttemptedAutoLoad = false
        hasAttemptedActivityCatalogLoad = false
        hasAttemptedActivityPlanLoad = false
        state = PlannerState()
    }

    var state: PlannerState = PlannerState()
        private set

    /** DEBUG-only deterministic demo payload for store screenshot captures. */
    fun seedStoreScreenshotDemo(language: String) {
        if (!com.hiair.BuildConfig.DEBUG) return
        val ru = language.startsWith("ru")
        val hourly = (6..23).map { hour ->
            val risk = when {
                hour in 12..16 -> "high"
                hour in 18..20 -> "low"
                else -> "moderate"
            }
            String.format("%02d:00", hour) + ":$risk"
        } + listOf("00:00:low", "03:00:low")
        state = state.copy(
            statusText = "",
            freshnessText = if (ru) "Обновлено только что" else "Updated just now",
            forecastAvailable = true,
            premiumRequired = false,
            peakLine = if (ru) "Пик загрязнения в 14:00" else "Pollution peak at 2:00 PM",
            safeWindows = listOf(
                if (ru) "18:40–20:20 · низкое загрязнение" else "18:40–20:20 · low pollution",
            ),
            ventilationWindows = listOf(
                if (ru) "21:00–22:30 · хороший обмен" else "21:00–22:30 · good air exchange",
            ),
            hourly = hourly,
            hourlyRiskLevels = hourly.map { it.substringAfterLast(":").trim() },
            currentRiskLevel = "moderate",
            currentRiskScore = 45,
            activityRecommendedStart = "19:00",
            activityForecastAvailable = true,
            activityPremiumRequired = false,
        )
    }

    /** True after the first auto or manual planner fetch attempt in this process. */
    var hasAttemptedAutoLoad: Boolean = false

    /** True after the first activity catalog fetch attempt in this process. */
    var hasAttemptedActivityCatalogLoad: Boolean = false

    /** True after the first activity plan fetch attempt in this process. */
    var hasAttemptedActivityPlanLoad: Boolean = false

    fun selectActivity(activityId: String) {
        if (activityId.isBlank() || activityId == state.selectedActivityId) return
        val catalogEntry = state.activityCatalog.firstOrNull { it.id == activityId }
        activityRequestGeneration.incrementAndGet()
        state = state.copy(
            selectedActivityId = activityId,
            selectedDurationMinutes = catalogEntry?.defaultDurationMinutes
                ?.takeIf { it in ACTION_DURATION_OPTIONS }
                ?: 30,
            selectedIntensity = catalogEntry?.defaultIntensity
                ?.takeIf { it in ACTION_INTENSITY_OPTIONS }
                ?: "moderate",
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityRecommendedStartRaw = "",
            earliestStartOverride = "",
            activityPlanStatusText = "",
            activityPremiumRequired = false,
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
        )
        ProductAnalytics.track("activity_type_selected", mapOf("activity" to activityId))
    }

    fun selectDurationMinutes(durationMinutes: Int) {
        if (durationMinutes !in ACTION_DURATION_OPTIONS || durationMinutes == state.selectedDurationMinutes) return
        activityRequestGeneration.incrementAndGet()
        state = state.copy(
            selectedDurationMinutes = durationMinutes,
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityRecommendedStartRaw = "",
            earliestStartOverride = "",
            activityPlanStatusText = "",
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
        )
        ProductAnalytics.track(
            "activity_duration_changed",
            mapOf("duration_bucket" to durationMinutes.toString()),
        )
    }

    fun selectIntensity(intensity: String) {
        val normalized = intensity.lowercase()
        if (normalized !in ACTION_INTENSITY_OPTIONS || normalized == state.selectedIntensity) return
        activityRequestGeneration.incrementAndGet()
        state = state.copy(
            selectedIntensity = normalized,
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityRecommendedStartRaw = "",
            earliestStartOverride = "",
            activityPlanStatusText = "",
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
        )
        ProductAnalytics.track("activity_intensity_changed", mapOf("intensity" to normalized))
    }

    fun selectTimePreference(preference: ActionTimePreference) {
        if (preference == state.selectedTimePreference) return
        activityRequestGeneration.incrementAndGet()
        state = state.copy(selectedTimePreference = preference, earliestStartOverride = "",
            activityWindows = emptyList(), activityRecommendedStart = "", activityRecommendedStartRaw = "")
        ProductAnalytics.track("action_time_preference_selected", mapOf("preference" to preference.id))
    }

    fun selectPlace(placeId: String) {
        if (placeId == state.selectedPlaceId) return
        activityRequestGeneration.incrementAndGet()
        state = state.copy(
            selectedPlaceId = placeId,
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityRecommendedStartRaw = "",
            earliestStartOverride = "",
        )
    }

    fun tryThirtyMinutesLater(): Boolean {
        val raw = state.activityRecommendedStartRaw.takeIf { it.isNotBlank() } ?: return false
        val shifted = shiftIsoByMinutesForUi(raw, 30) ?: return false
        activityRequestGeneration.incrementAndGet()
        state = state.copy(
            earliestStartOverride = shifted,
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityRecommendedStartRaw = "",
            activityPlanStatusText = "",
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
        )
        ProductAnalytics.track("activity_try_later", mapOf("offset_minutes" to "30"))
        return true
    }

    fun loadSavedPlaces(userId: String, accessToken: String?) {
        if (userId.isBlank()) return
        try {
            val raw = apiClient.listPlaces(userId, accessToken)
            val places = SettingsViewModel.parsePlacesList(raw)
            val selected = state.selectedPlaceId.takeIf { id ->
                id.isBlank() || places.any { it.id == id }
            } ?: ""
            state = state.copy(savedPlaces = places, selectedPlaceId = selected)
        } catch (_: Exception) {
            // Places are optional for planner; keep previous list on failure.
        }
    }

    fun markActivityPlanned(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
    ) {
        if (state.activityRecommendedStartRaw.isBlank()) return
        if (state.activityPlanningAccess == "basic") {
            state = state.copy(activityPlanMarked = true,
                activityPlanMarkStatus = l("planner.activity.accepted_local", preferredLanguage))
            ProductAnalytics.track("action_plan_accepted", mapOf("access" to "basic", "persistence" to "local"))
            return
        }
        recordProtectedDayEvent(
            userId = userId,
            accessToken = accessToken,
            profileId = profileId,
            preferredLanguage = preferredLanguage,
            eventType = "workout_moved",
            successKey = "planner.activity.mark_planned_done",
            analyticsEvent = "activity_plan_marked_planned",
        ) { marked, status, premiumRequired ->
            state = state.copy(
                activityPlanMarked = marked,
                activityPlanMarkStatus = status,
                activityPremiumRequired = premiumRequired,
            )
        }
    }

    fun markVentilationUsed(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
    ) {
        recordProtectedDayEvent(
            userId = userId,
            accessToken = accessToken,
            profileId = profileId,
            preferredLanguage = preferredLanguage,
            eventType = "ventilation_window_used",
            successKey = "planner.ventilation.mark_done",
            analyticsEvent = "ventilation_window_marked_used",
        ) { marked, status, premiumRequired ->
            state = state.copy(
                ventilationWindowMarked = marked,
                ventilationMarkStatus = status,
                activityPremiumRequired = premiumRequired,
            )
        }
    }

    private fun recordProtectedDayEvent(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
        eventType: String,
        successKey: String,
        analyticsEvent: String,
        onResult: (marked: Boolean, status: String, premiumRequired: Boolean) -> Unit,
    ) {
        if (userId.isBlank() || profileId.isBlank()) return
        try {
            apiClient.createProtectedDayEvent(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                eventType = eventType,
            )
            ProductAnalytics.track(analyticsEvent)
            ProductAnalytics.track("protected_day_event_recorded", mapOf("event_type" to eventType))
            if (eventType == "workout_moved") {
                ProductAnalytics.track("activity_plan_followed", mapOf("event_type" to eventType))
            }
            onResult(true, l(successKey, preferredLanguage), false)
        } catch (error: ApiHttpException) {
            val premiumRequired = error.statusCode == 402
            val status = if (premiumRequired) {
                l("planner.activity.premium_required", preferredLanguage)
            } else {
                l("planner.activity.mark_planned_failed", preferredLanguage)
            }
            onResult(false, status, premiumRequired)
        } catch (_: Exception) {
            onResult(false, l("planner.activity.mark_planned_failed", preferredLanguage), false)
        }
    }

    fun loadActivityCatalog(userId: String, accessToken: String?) {
        try {
            val raw = apiClient.fetchActivityCatalog(userId = userId, accessToken = accessToken)
            val catalog = parseActivityCatalog(raw)
            val selected = catalog.firstOrNull { it.id == state.selectedActivityId }
                ?: catalog.firstOrNull()
            state = state.copy(
                activityCatalog = catalog,
                selectedActivityId = selected?.id ?: DEFAULT_ACTIVITY_ID,
                selectedDurationMinutes = selected?.defaultDurationMinutes
                    ?.takeIf { it in ACTION_DURATION_OPTIONS }
                    ?: state.selectedDurationMinutes,
                selectedIntensity = selected?.defaultIntensity
                    ?.takeIf { it in ACTION_INTENSITY_OPTIONS }
                    ?: state.selectedIntensity,
            )
        } catch (_: Exception) {
            if (state.activityCatalog.isEmpty()) {
                val fallback = fallbackActivityCatalog()
                val selected = fallback.firstOrNull { it.id == state.selectedActivityId }
                    ?: fallback.first()
                state = state.copy(
                    activityCatalog = fallback,
                    selectedActivityId = selected.id,
                    selectedDurationMinutes = selected.defaultDurationMinutes,
                    selectedIntensity = selected.defaultIntensity,
                )
            }
        }
    }

    fun refreshActivityPlan(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
        allowTimezoneRetry: Boolean = true,
    ) {
        val generation = activityRequestGeneration.incrementAndGet()
        val actionState = state
        val responseZoneValid = runCatching { ZoneId.of(actionState.activityTimezone) }.isSuccess
        val zone = if (responseZoneValid && actionState.activityTimezonePlaceId == actionState.selectedPlaceId) {
            actionState.activityTimezone
        } else actionState.savedPlaces.firstOrNull { it.id == actionState.selectedPlaceId }?.timezone
            ?.takeIf { runCatching { ZoneId.of(it) }.isSuccess }.orEmpty()
        val bounds = actionState.selectedTimePreference.bounds(zone)
        val activityId = actionState.selectedActivityId.ifBlank { DEFAULT_ACTIVITY_ID }
        val catalogEntry = actionState.activityCatalog.firstOrNull { it.id == activityId }
        val duration = actionState.selectedDurationMinutes.takeIf { it in ACTION_DURATION_OPTIONS }
            ?: catalogEntry?.defaultDurationMinutes
            ?: 30
        val intensity = actionState.selectedIntensity.takeIf { it in ACTION_INTENSITY_OPTIONS }
            ?: catalogEntry?.defaultIntensity
            ?: "moderate"
        state = state.copy(
            activityPlanLoading = true,
            activityPlanStatusText = "",
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
        )
        ProductAnalytics.track(
            "activity_plan_fetch_started",
            mapOf(
                "activity" to activityId,
                "duration_bucket" to duration.toString(),
                "intensity" to intensity,
                "time_shifted" to actionState.earliestStartOverride.isNotBlank().toString(),
            ),
        )
        try {
            val raw = apiClient.createActivityPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                activity = activityId,
                durationMinutes = duration,
                intensity = intensity,
                earliestStart = actionState.earliestStartOverride.takeIf { it.isNotBlank() } ?: bounds.first,
                latestStart = bounds.second,
                placeId = actionState.selectedPlaceId.takeIf { it.isNotBlank() },
            )
            if (generation != activityRequestGeneration.get()) return
            val responseZone = JSONObject(raw).optString("timezone")
            state = state.copy(activityTimezone = responseZone, activityTimezonePlaceId = actionState.selectedPlaceId)
            if (actionState.selectedTimePreference != ActionTimePreference.ANY &&
                (bounds.first == null || zone != responseZone)) {
                if (allowTimezoneRetry && runCatching { ZoneId.of(responseZone) }.isSuccess) {
                    refreshActivityPlan(userId, accessToken, profileId, preferredLanguage, false)
                } else {
                    state = state.copy(activityPlanLoading = false, activityWindows = emptyList(),
                        activityRecommendedStart = "", activityRecommendedStartRaw = "",
                        activityPlanStatusText = l("planner.activity.forecast_unavailable", preferredLanguage))
                }
                return
            }
            val parsed = parseActivityPlan(raw, preferredLanguage)
            state = state.copy(
                activityTimezone = JSONObject(raw).optString("timezone"),
                activityPlanningAccess = JSONObject(raw).optString("planningAccess", "full"),
                activityPlanLoading = false,
                activityPlanStatusText = parsed.statusText,
                activityWindows = parsed.windows,
                activityRecommendedStart = parsed.recommendedStart,
                activityRecommendedStartRaw = parsed.recommendedStartRaw,
                activityPremiumRequired = false,
                activityForecastAvailable = parsed.forecastAvailable,
            )
            ProductAnalytics.track(
                "activity_plan_loaded",
                mapOf(
                    "activity" to activityId,
                    "duration_bucket" to duration.toString(),
                    "intensity" to intensity,
                    "windows" to parsed.windows.size.toString(),
                    "forecast" to parsed.forecastAvailable.toString(),
                ),
            )
            if (parsed.forecastAvailable && parsed.windows.isNotEmpty()) {
                ProductAnalytics.track(
                    "activity_plan_created",
                    mapOf(
                        "activity" to activityId,
                        "duration_bucket" to duration.toString(),
                        "intensity" to intensity,
                        "windows" to parsed.windows.size.toString(),
                    ),
                )
            }
        } catch (error: ApiHttpException) {
            if (generation != activityRequestGeneration.get()) return
            ProductAnalytics.track("activity_plan_fetch_failed", mapOf("activity" to activityId))
            val premiumRequired = error.statusCode == 402
            state = state.copy(
                activityPlanLoading = false,
                activityPlanStatusText = if (premiumRequired) {
                    l("planner.activity.premium_required", preferredLanguage)
                } else {
                    l("planner.activity.failed", preferredLanguage)
                },
                activityWindows = emptyList(),
                activityRecommendedStart = "",
                activityRecommendedStartRaw = "",
                activityPremiumRequired = premiumRequired,
                activityForecastAvailable = false,
            )
        } catch (_: Exception) {
            if (generation != activityRequestGeneration.get()) return
            ProductAnalytics.track("activity_plan_fetch_failed", mapOf("activity" to activityId))
            state = state.copy(
                activityPlanLoading = false,
                activityPlanStatusText = l("planner.activity.failed", preferredLanguage),
                activityWindows = emptyList(),
                activityRecommendedStart = "",
                activityRecommendedStartRaw = "",
                activityPremiumRequired = false,
                activityForecastAvailable = false,
            )
        }
    }

    fun refresh(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        state = state.copy(
            loading = true,
            ventilationWindowMarked = false,
            ventilationMarkStatus = "",
        )
        ProductAnalytics.track("forecast_fetch_started", mapOf("surface" to "planner"))
        try {
            val raw = apiClient.fetchAirDayPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
            )
            val actionState = state
            state = parsePlan(raw, preferredLanguage).copy(
                activityCatalog = actionState.activityCatalog,
                selectedActivityId = actionState.selectedActivityId,
                selectedDurationMinutes = actionState.selectedDurationMinutes,
                selectedIntensity = actionState.selectedIntensity,
                selectedPlaceId = actionState.selectedPlaceId,
                savedPlaces = actionState.savedPlaces,
                activityPlanMarked = actionState.activityPlanMarked,
                activityPlanMarkStatus = actionState.activityPlanMarkStatus,
                activityPlanLoading = actionState.activityPlanLoading,
                activityPlanStatusText = actionState.activityPlanStatusText,
                activityWindows = actionState.activityWindows,
                activityRecommendedStart = actionState.activityRecommendedStart,
                activityRecommendedStartRaw = actionState.activityRecommendedStartRaw,
                earliestStartOverride = actionState.earliestStartOverride,
                selectedTimePreference = actionState.selectedTimePreference,
                activityTimezone = actionState.activityTimezone,
                activityTimezonePlaceId = actionState.activityTimezonePlaceId,
                activityPlanningAccess = actionState.activityPlanningAccess,
                activityPremiumRequired = actionState.activityPremiumRequired,
                activityForecastAvailable = actionState.activityForecastAvailable,
            )
            if (!state.forecastAvailable) {
                ProductAnalytics.track(
                    "planner_forecast_unavailable",
                    mapOf("quality" to state.dataQuality.ifBlank { "unknown" }),
                )
            } else {
                ProductAnalytics.track(
                    "planner_real_forecast_loaded",
                    mapOf(
                        "quality" to state.dataQuality.ifBlank { "complete" },
                        "hours" to state.hourly.size.toString(),
                        "freshness" to state.freshness,
                    ),
                )
            }
        } catch (error: ApiHttpException) {
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "planner"))
            val premiumRequired = error.statusCode == 402
            state = state.copy(
                loading = false,
                statusText = if (premiumRequired) {
                    l("planner.premium_required", preferredLanguage)
                } else {
                    l("planner.failed", preferredLanguage)
                },
                freshnessText = "",
                safeWindows = emptyList(),
                ventilationWindows = emptyList(),
                hourly = emptyList(),
                hourlyRiskLevels = emptyList(),
                currentRiskLevel = "",
                currentRiskScore = 0,
                peakLine = "",
                premiumRequired = premiumRequired,
                forecastAvailable = false,
            )
        } catch (_: Exception) {
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "planner"))
            state = state.copy(
                loading = false,
                statusText = l("planner.failed", preferredLanguage),
                freshnessText = "",
                safeWindows = emptyList(),
                ventilationWindows = emptyList(),
                hourly = emptyList(),
                hourlyRiskLevels = emptyList(),
                currentRiskLevel = "",
                currentRiskScore = 0,
                peakLine = "",
                premiumRequired = false,
                forecastAvailable = false,
            )
        }
    }

    companion object {
        const val DEFAULT_ACTIVITY = DEFAULT_ACTIVITY_ID

        data class ActivityPlanParseResult(
            val statusText: String,
            val windows: List<ActivityWindowLine>,
            val recommendedStart: String,
            val recommendedStartRaw: String,
            val forecastAvailable: Boolean,
        )

        fun durationOptionsForUi(): List<Int> = ACTION_DURATION_OPTIONS

        fun intensityOptionsForUi(): List<String> = ACTION_INTENSITY_OPTIONS

        fun shiftIsoByMinutesForUi(raw: String, minutes: Long): String? =
            runCatching { OffsetDateTime.parse(raw).plusMinutes(minutes).toString() }.getOrNull()

        fun parseActivityCatalog(raw: String): List<ActivityCatalogEntry> {
            val json = JSONObject(raw)
            val activities = json.optJSONArray("activities") ?: JSONArray()
            val items = mutableListOf<ActivityCatalogEntry>()
            for (i in 0 until activities.length()) {
                val item = activities.getJSONObject(i)
                val id = item.optString("activity")
                if (id.isBlank()) continue
                items.add(
                    ActivityCatalogEntry(
                        id = id,
                        defaultDurationMinutes = item.optInt("defaultDurationMinutes", 30),
                        defaultIntensity = item.optString("defaultIntensity", "moderate"),
                        outdoor = item.optBoolean("outdoor", true),
                    )
                )
            }
            return items
        }

        fun parseActivityPlan(raw: String, preferredLanguage: String): ActivityPlanParseResult {
            val json = JSONObject(raw)
            val timezone = json.optString("timezone").takeIf { it.isNotBlank() }
            val zoneId = HiAirHumanDate.zoneId(timezone)
            val forecastAvailable = if (json.has("forecastAvailable") && !json.isNull("forecastAvailable")) {
                json.optBoolean("forecastAvailable")
            } else {
                (json.optJSONArray("windows")?.length() ?: 0) > 0
            }
            val windows = json.optJSONArray("windows") ?: JSONArray()
            val windowLines = mutableListOf<ActivityWindowLine>()
            if (forecastAvailable) {
                for (i in 0 until windows.length()) {
                    val item = windows.getJSONObject(i)
                    val tier = item.optString("tier")
                    val range = HiAirHumanDate.timeRangeIso(
                        item.getString("start"),
                        item.getString("end"),
                        Locale.getDefault(),
                        "",
                        zoneId,
                    )
                    val tierLabel = localizedActivityTier(tier, preferredLanguage)
                    val line = if (range.isBlank()) tierLabel else "$tierLabel: $range"
                    val codes = item.optJSONArray("reasonCodes") ?: JSONArray()
                    val reasons = (0 until codes.length()).mapNotNull { index ->
                        val code = codes.optString(index)
                        val normalized = when {
                            code in listOf("heat", "air", "uv", "low_heat", "good_air", "personal_load", "child_caution", "air_data_unavailable") -> code
                            code.contains("heat") || code == "high_humidity" -> "heat"
                            code.contains("uv") -> "uv"
                            code in listOf("no2_elevated", "pm10_elevated", "ozone_elevated", "profile_respiratory_sensitivity", "aqi", "pm25", "ozone") -> "air"
                            else -> code
                        }
                        val key = "planner.activity.reason.$normalized"
                        l(key, preferredLanguage).takeIf { it != key }
                    }.distinct().take(3).joinToString(" · ")
                    windowLines.add(ActivityWindowLine(tier = tier,
                        line = if (reasons.isBlank()) line else "$line\n$reasons"))
                }
            }
            val recommendedStartRaw = json.optString("recommendedStart")
                .takeIf { !json.isNull("recommendedStart") && forecastAvailable &&
                    runCatching { OffsetDateTime.parse(it) }.isSuccess }
                .orEmpty()
            val recommendedStart = recommendedStartRaw
                .takeIf { it.isNotBlank() }
                ?.let { formatActivityTime(it, preferredLanguage, zoneId) }
                .orEmpty()
            val statusText = when {
                !forecastAvailable -> l("planner.activity.forecast_unavailable", preferredLanguage)
                windowLines.isEmpty() -> l("planner.activity.no_windows", preferredLanguage)
                else -> l("planner.activity.loaded", preferredLanguage)
                    .replaceFirst("%d", windowLines.size.toString())
            }
            return ActivityPlanParseResult(
                statusText = statusText,
                windows = windowLines,
                recommendedStart = recommendedStart,
                recommendedStartRaw = recommendedStartRaw,
                forecastAvailable = forecastAvailable,
            )
        }

        fun fallbackActivityCatalogForUi(): List<ActivityCatalogEntry> = fallbackActivityCatalog()

        private fun fallbackActivityCatalog(): List<ActivityCatalogEntry> = listOf(
            ActivityCatalogEntry("running", 45, "high"),
            ActivityCatalogEntry("walking", 30, "low"),
            ActivityCatalogEntry("cycling", 60, "moderate"),
            ActivityCatalogEntry("hiking", 90, "moderate"),
            ActivityCatalogEntry("dog_walk", 30, "low"),
            ActivityCatalogEntry("playground", 60, "low"),
            ActivityCatalogEntry("outdoor_sport", 60, "high"),
            ActivityCatalogEntry("beach", 120, "moderate"),
            ActivityCatalogEntry("outdoor_work", 120, "moderate"),
            ActivityCatalogEntry("ventilation", 60, "low", outdoor = false),
        )

        private fun localizedActivityTier(tier: String, preferredLanguage: String): String {
            return when (tier.lowercase()) {
                "best" -> l("planner.activity.tier.best", preferredLanguage)
                "acceptable" -> l("planner.activity.tier.acceptable", preferredLanguage)
                "avoid" -> l("planner.activity.tier.avoid", preferredLanguage)
                else -> tier
            }
        }

        private fun localizedActivityName(activityId: String, preferredLanguage: String): String {
            val key = "planner.activity.type.$activityId"
            val localized = l(key, preferredLanguage)
            return if (localized == key) activityId else localized
        }

        fun activityDisplayLabels(
            catalog: List<ActivityCatalogEntry>,
            preferredLanguage: String,
        ): List<String> = catalog.map { localizedActivityName(it.id, preferredLanguage) }

        private fun formatActivityTime(raw: String, preferredLanguage: String, zoneId: ZoneId): String {
            val locale = Locale.forLanguageTag(preferredLanguage)
            HiAirHumanDate.formatIso(raw, locale, HiAirHumanDate.Style.TIME, zoneId)?.let { return it }
            if (raw.length >= 2 && raw.substring(0, 2).all { it.isDigit() } && !raw.contains("T")) {
                return raw.take(5)
            }
            return raw
        }

        fun parsePlan(raw: String, preferredLanguage: String): PlannerState {
            val json = JSONObject(raw)
            val timezone = json.optString("timezone").takeIf { it.isNotBlank() }
            val zoneId = HiAirHumanDate.zoneId(timezone)
            val hourly = json.optJSONArray("hourlyRisk") ?: JSONArray()
            val forecastAvailable = if (json.has("forecastAvailable") && !json.isNull("forecastAvailable")) {
                json.optBoolean("forecastAvailable")
            } else {
                hourly.length() > 0
            }
            val dataQuality = json.optString("dataQuality")
            val freshness = json.optString("freshness")
            val missingMetrics = mutableListOf<String>()
            json.optJSONArray("missingMetrics")?.let { array ->
                for (i in 0 until array.length()) {
                    val value = array.optString(i)
                    if (value.isNotBlank()) missingMetrics.add(value)
                }
            }
            val sources = mutableListOf<String>()
            json.optJSONArray("sources")?.let { array ->
                for (i in 0 until array.length()) {
                    val value = array.optString(i)
                    if (value.isNotBlank()) sources.add(value)
                }
            }

            val safeWindowItems = mutableListOf<String>()
            val safeWindows = json.optJSONArray("safeWindows") ?: JSONArray()
            if (forecastAvailable) {
                for (i in 0 until safeWindows.length()) {
                    val item = safeWindows.getJSONObject(i)
                    val type = item.getString("type")
                    if (type.equals("ventilation", ignoreCase = true)) continue
                    safeWindowItems.add(
                        formatSafeWindow(
                            type = type,
                            start = item.getString("start"),
                            end = item.getString("end"),
                            preferredLanguage = preferredLanguage,
                            zoneId = zoneId,
                        )
                    )
                }
            }
            val ventilationItems = mutableListOf<String>()
            val ventilationWindows = json.optJSONArray("ventilationWindows") ?: JSONArray()
            if (forecastAvailable) {
                for (i in 0 until ventilationWindows.length()) {
                    val item = ventilationWindows.getJSONObject(i)
                    val range = HiAirHumanDate.timeRangeIso(
                        item.getString("start"),
                        item.getString("end"),
                        Locale.getDefault(),
                        "",
                        zoneId,
                    )
                    if (range.isNotBlank()) ventilationItems.add(range)
                }
            }
            val hourlyItems = mutableListOf<String>()
            val hourlyRiskLevels = mutableListOf<String>()
            if (forecastAvailable) {
                for (i in 0 until hourly.length()) {
                    val item = hourly.getJSONObject(i)
                    val hourLabel = humanHour(item.getString("hour"), preferredLanguage, zoneId)
                    val riskRaw = item.getString("overallRisk")
                    val riskLabel = localizedRisk(riskRaw, preferredLanguage)
                    hourlyItems.add("$hourLabel: $riskLabel")
                    hourlyRiskLevels.add(riskRaw)
                }
            }
            val currentRiskLevel = currentHourRisk(hourly, hourlyRiskLevels)
            val currentRiskScore = riskScoreFor(currentRiskLevel)
            val statusText = when {
                !forecastAvailable -> l("planner.forecast_unavailable", preferredLanguage)
                dataQuality.equals("partial", ignoreCase = true) -> {
                    val base = l("planner.forecast_partial", preferredLanguage)
                    if (missingMetrics.isEmpty()) base
                    else "$base (${missingMetrics.take(4).joinToString(", ")})"
                }
                else -> l("planner.loaded", preferredLanguage)
                    .replaceFirst("%d", hourly.length().toString())
            }
            val freshnessText = if (forecastAvailable) freshnessCaption(freshness, preferredLanguage) else ""
            val sourcesText = if (forecastAvailable && sources.isNotEmpty()) {
                "${l("planner.sources", preferredLanguage)}: ${sources.joinToString(", ")}"
            } else {
                ""
            }
            return PlannerState(
                loading = false,
                statusText = statusText,
                freshnessText = listOf(freshnessText, sourcesText).filter { it.isNotBlank() }.joinToString("\n"),
                safeWindows = safeWindowItems,
                ventilationWindows = ventilationItems,
                hourly = hourlyItems,
                hourlyRiskLevels = hourlyRiskLevels,
                currentRiskLevel = currentRiskLevel,
                currentRiskScore = currentRiskScore,
                peakLine = buildPeakLine(hourly, preferredLanguage, zoneId),
                premiumRequired = false,
                forecastAvailable = forecastAvailable,
                dataQuality = dataQuality,
                freshness = freshness,
                missingMetrics = missingMetrics,
                sources = sources,
            )
        }

        private fun freshnessCaption(freshness: String, preferredLanguage: String): String {
            return when (freshness.lowercase()) {
                "cached" -> l("planner.freshness.cached", preferredLanguage)
                "stale" -> l("planner.freshness.stale", preferredLanguage)
                "live" -> l("planner.freshness.live", preferredLanguage)
                else -> if (freshness.isBlank()) "" else l("planner.freshness.live", preferredLanguage)
            }
        }

        private fun buildPeakLine(hourly: JSONArray, preferredLanguage: String, zoneId: ZoneId): String {
            if (hourly.length() == 0) return ""
            var peakIndex = 0
            var peakWeight = -1
            for (i in 0 until hourly.length()) {
                val risk = hourly.getJSONObject(i).getString("overallRisk")
                val weight = riskWeight(risk)
                if (weight > peakWeight) {
                    peakWeight = weight
                    peakIndex = i
                }
            }
            val peak = hourly.getJSONObject(peakIndex)
            val riskLabel = localizedRisk(peak.getString("overallRisk"), preferredLanguage)
            val hourLabel = humanHour(peak.getString("hour"), preferredLanguage, zoneId)
            return l("planner.peak_line", preferredLanguage)
                .replaceFirst("%@", riskLabel)
                .replaceFirst("%@", hourLabel)
        }

        private fun formatSafeWindow(
            type: String,
            start: String,
            end: String,
            preferredLanguage: String,
            zoneId: ZoneId,
        ): String {
            val typeKey = when (type.lowercase()) {
                "walk", "outdoor", "safe", "sport", "exercise", "run" -> "planner.window.safe"
                "ventilation", "ventilate" -> "planner.window.ventilation"
                else -> "dashboard.safe_window"
            }
            val label = l(typeKey, preferredLanguage)
            val range = HiAirHumanDate.timeRangeIso(
                start,
                end,
                Locale.getDefault(),
                "",
                zoneId,
            )
            return if (range.isEmpty()) label else "$label: $range"
        }

        private fun humanHour(raw: String, preferredLanguage: String, zoneId: ZoneId): String {
            val locale = Locale.forLanguageTag(preferredLanguage)
            HiAirHumanDate.formatIso(raw, locale, HiAirHumanDate.Style.TIME, zoneId)?.let { return it }
            if (raw.length >= 2 && raw.substring(0, 2).all { it.isDigit() } && !raw.contains("T")) {
                return raw.take(5)
            }
            return raw
        }

        private fun localizedRisk(risk: String, preferredLanguage: String): String {
            return when (risk.lowercase()) {
                "low" -> l("dashboard.mood.calm", preferredLanguage)
                "moderate", "medium" -> l("dashboard.mood.aware", preferredLanguage)
                "high" -> l("dashboard.mood.cautious", preferredLanguage)
                "very_high", "very high" -> l("dashboard.mood.protective", preferredLanguage)
                else -> l("dashboard.mood.calm", preferredLanguage)
            }
        }

        private fun riskWeight(risk: String): Int {
            return when (risk.lowercase()) {
                "low" -> 1
                "moderate", "medium" -> 2
                "high" -> 3
                "very_high", "very high" -> 4
                else -> 0
            }
        }

        fun riskScoreFor(risk: String): Int {
            return when (risk.lowercase()) {
                "low" -> 20
                "moderate", "medium" -> 45
                "high" -> 70
                "very_high", "very high" -> 90
                else -> 0
            }
        }

        private fun currentHourRisk(hourly: JSONArray, levels: List<String>): String {
            if (levels.isEmpty()) return ""
            val nowHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            for (i in 0 until hourly.length()) {
                val rawHour = hourly.optJSONObject(i)?.optString("hour").orEmpty()
                val parsed = rawHour.take(2).toIntOrNull()
                    ?: Regex("""T(\d{2})""").find(rawHour)?.groupValues?.getOrNull(1)?.toIntOrNull()
                if (parsed == nowHour) {
                    return levels.getOrElse(i) { levels.first() }
                }
            }
            return levels.first()
        }

        private fun l(key: String, preferredLanguage: String): String =
            AndroidL10n.t(key, preferredLanguage)
    }
}
