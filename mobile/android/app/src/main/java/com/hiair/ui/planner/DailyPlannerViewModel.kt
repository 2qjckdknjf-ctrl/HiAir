package com.hiair.ui.planner

import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.ApiHttpException
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.settings.SavedPlaceItem
import com.hiair.ui.settings.SettingsViewModel
import com.hiair.ui.i18n.AndroidL10n
import java.time.ZoneId
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

private const val DEFAULT_ACTIVITY_ID = "walking"

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
    val peakLine: String = "",
    val premiumRequired: Boolean = false,
    val forecastAvailable: Boolean = true,
    val dataQuality: String = "",
    val freshness: String = "",
    val missingMetrics: List<String> = emptyList(),
    val sources: List<String> = emptyList(),
    val activityCatalog: List<ActivityCatalogEntry> = emptyList(),
    val selectedActivityId: String = DEFAULT_ACTIVITY_ID,
    val selectedPlaceId: String = "",
    val savedPlaces: List<SavedPlaceItem> = emptyList(),
    val activityPlanMarked: Boolean = false,
    val activityPlanMarkStatus: String = "",
    val activityPlanLoading: Boolean = false,
    val activityPlanStatusText: String = "",
    val activityWindows: List<ActivityWindowLine> = emptyList(),
    val activityRecommendedStart: String = "",
    val activityPremiumRequired: Boolean = false,
    val activityForecastAvailable: Boolean = true,
)

class DailyPlannerViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    var state: PlannerState = PlannerState()
        private set

    /** True after the first auto or manual planner fetch attempt in this process. */
    var hasAttemptedAutoLoad: Boolean = false

    /** True after the first activity catalog fetch attempt in this process. */
    var hasAttemptedActivityCatalogLoad: Boolean = false

    /** True after the first activity plan fetch attempt in this process. */
    var hasAttemptedActivityPlanLoad: Boolean = false

    fun selectActivity(activityId: String) {
        if (activityId.isBlank() || activityId == state.selectedActivityId) return
        state = state.copy(
            selectedActivityId = activityId,
            activityWindows = emptyList(),
            activityRecommendedStart = "",
            activityPlanStatusText = "",
            activityPremiumRequired = false,
        )
    }

    fun selectPlace(placeId: String) {
        if (placeId == state.selectedPlaceId) return
        state = state.copy(
            selectedPlaceId = placeId,
            activityPlanMarked = false,
            activityPlanMarkStatus = "",
            activityWindows = emptyList(),
            activityRecommendedStart = "",
        )
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
            // Places are optional for planner.
        }
    }

    fun markActivityPlanned(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
    ) {
        if (userId.isBlank() || profileId.isBlank()) return
        try {
            apiClient.createProtectedDayEvent(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                eventType = "workout_moved",
            )
            state = state.copy(
                activityPlanMarked = true,
                activityPlanMarkStatus = l("planner.activity.mark_planned_done", preferredLanguage),
            )
            ProductAnalytics.track("activity_plan_marked_planned")
        } catch (error: ApiHttpException) {
            val status = if (error.statusCode == 402) {
                l("planner.activity.premium_required", preferredLanguage)
            } else {
                l("planner.activity.mark_planned_failed", preferredLanguage)
            }
            state = state.copy(
                activityPlanMarkStatus = status,
                activityPremiumRequired = error.statusCode == 402,
            )
        } catch (_: Exception) {
            state = state.copy(
                activityPlanMarkStatus = l("planner.activity.mark_planned_failed", preferredLanguage),
            )
        }
    }

    fun loadActivityCatalog(userId: String, accessToken: String?) {
        try {
            val raw = apiClient.fetchActivityCatalog(
                userId = userId,
                accessToken = accessToken,
            )
            val catalog = parseActivityCatalog(raw)
            val selected = catalog.firstOrNull { it.id == state.selectedActivityId }?.id
                ?: catalog.firstOrNull()?.id
                ?: DEFAULT_ACTIVITY_ID
            state = state.copy(
                activityCatalog = catalog,
                selectedActivityId = selected,
            )
        } catch (_: Exception) {
            if (state.activityCatalog.isEmpty()) {
                state = state.copy(
                    activityCatalog = fallbackActivityCatalog(),
                    selectedActivityId = state.selectedActivityId.ifBlank { DEFAULT_ACTIVITY_ID },
                )
            }
        }
    }

    fun refreshActivityPlan(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
    ) {
        val activityId = state.selectedActivityId.ifBlank { DEFAULT_ACTIVITY_ID }
        val catalogEntry = state.activityCatalog.firstOrNull { it.id == activityId }
        state = state.copy(activityPlanLoading = true, activityPlanStatusText = "", activityPlanMarked = false, activityPlanMarkStatus = "")
        ProductAnalytics.track(
            "activity_plan_fetch_started",
            mapOf("activity" to activityId),
        )
        try {
            val raw = apiClient.createActivityPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                activity = activityId,
                durationMinutes = catalogEntry?.defaultDurationMinutes,
                intensity = catalogEntry?.defaultIntensity,
                placeId = state.selectedPlaceId.takeIf { it.isNotBlank() },
            )
            val parsed = parseActivityPlan(raw, preferredLanguage)
            state = state.copy(
                activityPlanLoading = false,
                activityPlanStatusText = parsed.statusText,
                activityWindows = parsed.windows,
                activityRecommendedStart = parsed.recommendedStart,
                activityPremiumRequired = false,
                activityForecastAvailable = parsed.forecastAvailable,
            )
            ProductAnalytics.track(
                "activity_plan_loaded",
                mapOf(
                    "activity" to activityId,
                    "windows" to parsed.windows.size.toString(),
                    "forecast" to parsed.forecastAvailable.toString(),
                ),
            )
        } catch (error: ApiHttpException) {
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
                activityPremiumRequired = premiumRequired,
                activityForecastAvailable = false,
            )
        } catch (_: Exception) {
            ProductAnalytics.track("activity_plan_fetch_failed", mapOf("activity" to activityId))
            state = state.copy(
                activityPlanLoading = false,
                activityPlanStatusText = l("planner.activity.failed", preferredLanguage),
                activityWindows = emptyList(),
                activityRecommendedStart = "",
                activityPremiumRequired = false,
                activityForecastAvailable = false,
            )
        }
    }

    fun refresh(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        state = state.copy(loading = true)
        ProductAnalytics.track("forecast_fetch_started", mapOf("surface" to "planner"))
        try {
            val raw = apiClient.fetchAirDayPlan(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId
            )
            state = parsePlan(raw, preferredLanguage)
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
            val forecastAvailable: Boolean,
        )

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
                    windowLines.add(ActivityWindowLine(tier = tier, line = line))
                }
            }
            val recommendedStart = json.optString("recommendedStart")
                .takeIf { it.isNotBlank() && forecastAvailable }
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
                    if (range.isNotBlank()) {
                        ventilationItems.add(range)
                    }
                }
            }
            val hourlyItems = mutableListOf<String>()
            if (forecastAvailable) {
                for (i in 0 until hourly.length()) {
                    val item = hourly.getJSONObject(i)
                    val hourLabel = humanHour(item.getString("hour"), preferredLanguage, zoneId)
                    val riskLabel = localizedRisk(item.getString("overallRisk"), preferredLanguage)
                    hourlyItems.add("$hourLabel: $riskLabel")
                }
            }
            val statusText = when {
                !forecastAvailable -> l("planner.forecast_unavailable", preferredLanguage)
                dataQuality.equals("partial", ignoreCase = true) -> {
                    val base = l("planner.forecast_partial", preferredLanguage)
                    if (missingMetrics.isEmpty()) {
                        base
                    } else {
                        "$base (${missingMetrics.take(4).joinToString(", ")})"
                    }
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

        private fun l(key: String, preferredLanguage: String): String =
            AndroidL10n.t(key, preferredLanguage)
    }
}
