package com.hiair.ui

import com.hiair.ui.settings.SettingsViewModel
import com.hiair.analytics.ProductAnalytics
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.ui.design.HiAirHumanDate
import com.hiair.ui.family.FamilyMemberRiskItem
import com.hiair.ui.family.FamilyRiskParser
import com.hiair.ui.i18n.AndroidL10n
import java.io.IOException
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.time.ZoneId
import java.util.Locale
import java.util.concurrent.atomic.AtomicLong
import org.json.JSONObject

/**
 * Single source of truth for the dashboard screen. The screen is always in
 * exactly one of these states; the renderer paints purely from this state and
 * never substitutes placeholder/demo values.
 */
enum class DashboardStatus {
    INITIAL,
    LOADING,
    SUCCESS,
    EMPTY,
    ERROR,
    OFFLINE,
}

data class HazardLine(
    val hazard: String,
    val level: String,
    val score: Int,
    val available: Boolean,
)

data class DashboardState(
    val status: DashboardStatus = DashboardStatus.INITIAL,
    val riskLevel: String? = null,
    val riskScore: Int? = null,
    val headline: String? = null,
    val explanation: String? = null,
    val actions: List<String> = emptyList(),
    val safeWindows: List<String> = emptyList(),
    val dataSource: String? = null,
    val aqi: Int? = null,
    val pm25: Double? = null,
    val ozone: Double? = null,
    val no2: Double? = null,
    val temperatureC: Double? = null,
    val feelsLikeC: Double? = null,
    val humidityPercent: Double? = null,
    val freshness: String? = null,
    val dataQuality: String? = null,
    val timezone: String? = null,
    val wearableSteps: Int? = null,
    val wearableLoadLevel: String? = null,
    val wearableSummary: String? = null,
    val wearableConnected: Boolean = false,
    val healthSummaryRaw: String? = null,
    val hazardsOverallLevel: String? = null,
    val hazardsOverallScore: Int? = null,
    val hazardLines: List<HazardLine> = emptyList(),
    val familyRiskLines: List<FamilyMemberRiskItem> = emptyList(),
    val familyHighestRisk: String? = null,
    val exposureReducedMarked: Boolean = false,
    val highRiskAvoidedMarked: Boolean = false,
    val protectedDayStatus: String = "",
    val travelActive: Boolean = false,
    val travelPlaceName: String? = null,
)

class DashboardViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    private val loadGeneration = AtomicLong()
    @Volatile
    var state: DashboardState = DashboardState()
        private set

    /**
     * Marks the screen as loading on the UI thread before the background load
     * starts. This prevents a re-render from spawning a duplicate request while
     * the first one is still in flight.
     */
    @Synchronized
    fun markLoading(): Long {
        val generation = loadGeneration.incrementAndGet()
        state = state.copy(status = DashboardStatus.LOADING)
        return generation
    }

    /** Resets the screen to its initial state, e.g. after sign-out. */
    @Synchronized
    fun reset() {
        loadGeneration.incrementAndGet()
        state = DashboardState()
    }

    fun ownsLoadGeneration(generation: Long): Boolean = generation == loadGeneration.get()

    /** Release only this queued/in-flight load; a newer account's load wins. */
    @Synchronized
    fun cancelLoad(generation: Long): Boolean {
        if (!ownsLoadGeneration(generation)) return false
        state = DashboardState(
            status = if (ApiClient.authenticatedUserId() == null) DashboardStatus.EMPTY else DashboardStatus.INITIAL,
        )
        return true
    }

    /** Reconcile the owner again when the queued completion reaches the UI. */
    @Synchronized
    fun finishLoadForRender(generation: Long, userId: String): Boolean {
        if (!ownsLoadGeneration(generation)) return false
        if (!ApiClient.isCurrentUser(userId)) return cancelLoad(generation)
        return true
    }

    @Synchronized
    private fun isCurrentLoad(generation: Long, userId: String): Boolean {
        if (!ownsLoadGeneration(generation)) return false
        if (ApiClient.isCurrentUser(userId)) return true
        cancelLoad(generation)
        return false
    }

    @Synchronized
    private fun beginCurrentLoad(userId: String, accessToken: String?, profileId: String?, pendingGeneration: Long?): Long? {
        if (pendingGeneration != null && !ownsLoadGeneration(pendingGeneration)) return null
        val activeUserId = ApiClient.authenticatedUserId()
        if (activeUserId != null && activeUserId != userId) {
            if (pendingGeneration != null) cancelLoad(pendingGeneration)
            return null
        }
        if (userId.isBlank() || accessToken.isNullOrBlank() || profileId.isNullOrBlank()) {
            if (pendingGeneration == null) loadGeneration.incrementAndGet()
            state = DashboardState(status = DashboardStatus.EMPTY)
            return null
        }
        if (activeUserId == null) {
            if (pendingGeneration == null) loadGeneration.incrementAndGet()
            state = DashboardState(status = DashboardStatus.EMPTY)
            return null
        }
        val generation = pendingGeneration ?: loadGeneration.incrementAndGet()
        state = state.copy(
            status = DashboardStatus.LOADING,
            exposureReducedMarked = false,
            highRiskAvoidedMarked = false,
            protectedDayStatus = "",
        )
        return generation
    }

    @Synchronized
    private fun applyCurrentLoad(generation: Long, userId: String, next: DashboardState, onReady: (() -> Unit)? = null): Boolean {
        if (!isCurrentLoad(generation, userId)) return false
        state = next
        onReady?.invoke()
        return true
    }

    /** DEBUG-only deterministic demo payload for store screenshot captures. */
    fun seedStoreScreenshotDemo(language: String) {
        if (!com.hiair.BuildConfig.DEBUG) return
        state = DashboardState(
            status = DashboardStatus.SUCCESS,
            riskLevel = "moderate",
            riskScore = 55,
            headline = if (language.startsWith("ru")) "Умеренный риск на улице" else "Moderate outdoor risk",
            explanation = if (language.startsWith("ru")) {
                "Воздух комфортный; жара усиливается к полудню."
            } else {
                "Air is comfortable; heat rises toward midday."
            },
            actions = listOf(
                if (language.startsWith("ru")) "Пить воду" else "Carry water",
                if (language.startsWith("ru")) "Гулять утром или вечером" else "Walk morning or evening",
            ),
            safeWindows = listOf("07:00–09:30", "18:00–20:00"),
            dataSource = "live",
            aqi = 52,
            pm25 = 11.0,
            ozone = 42.0,
            temperatureC = 27.0,
            feelsLikeC = 28.0,
            humidityPercent = 48.0,
            freshness = "live",
            dataQuality = "complete",
            timezone = "Europe/Madrid",
            wearableSteps = 7421,
            wearableLoadLevel = "low",
            wearableSummary = if (language.startsWith("ru")) "Низкая нагрузка" else "Low personal load",
            wearableConnected = true,
            hazardsOverallLevel = "moderate",
            hazardsOverallScore = 55,
            hazardLines = listOf(
                HazardLine("heat", "moderate", 55, true),
                HazardLine("air", "low", 25, true),
            ),
            protectedDayStatus = "",
        )
    }

    /**
     * Loads real risk data for the given profile. Must be called from a
     * background thread. On failure the previous values are discarded so the UI
     * never presents stale data as fresh.
     */
    fun load(
        userId: String,
        accessToken: String?,
        profileId: String?,
        preferredLanguage: String,
        isRetry: Boolean = false,
        pendingGeneration: Long? = null,
        onRiskReady: (() -> Unit)? = null,
    ) {
        // Ownership, generation allocation and the initial state share the same
        // monitor as reset/apply, so an old start cannot invalidate a newer load.
        val generation = beginCurrentLoad(userId, accessToken, profileId, pendingGeneration) ?: return
        if (!isCurrentLoad(generation, userId)) return
        if (isRetry) {
            ProductAnalytics.track("dashboard_retry")
        }
        // beginCurrentLoad has validated the nullable input; keep local non-null
        // values for the API calls below without changing request ownership.
        val requestProfileId = profileId ?: return
        ProductAnalytics.track("dashboard_loading")
        ProductAnalytics.track("forecast_fetch_started", mapOf("surface" to "dashboard"))
        try {
            val raw = apiClient.fetchCurrentRisk(
                userId = userId,
                accessToken = accessToken,
                profileId = requestProfileId,
            )
            val parsed = parseCurrentRisk(raw, preferredLanguage)
            // Paint risk immediately; wearable/health enrich without blocking SUCCESS.
            if (!applyCurrentLoad(generation, userId, parsed, onRiskReady)) return
            ProductAnalytics.track(
                "dashboard_loaded",
                mapOf("source" to (parsed.dataSource ?: "unknown")),
            )
            ProductAnalytics.track(
                "forecast_fetch_succeeded",
                mapOf(
                    "freshness" to (parsed.freshness ?: parsed.dataSource ?: ""),
                    "quality" to (parsed.dataQuality ?: ""),
                    "hours" to parsed.safeWindows.size.toString(),
                ),
            )
            ProductAnalytics.recordAppOpen(surface = "dashboard", userId = userId)
            if (!parsed.headline.isNullOrBlank() || !parsed.explanation.isNullOrBlank()) {
                ProductAnalytics.recordUsefulRecommendation(surface = "dashboard", userId = userId)
            }
            if (!isCurrentLoad(generation, userId)) return
            var enriched = withWearable(parsed, userId, accessToken, generation)
            if (!isCurrentLoad(generation, userId)) return
            enriched = withHazards(enriched, userId, accessToken, requestProfileId)
            if (!isCurrentLoad(generation, userId)) return
            enriched = withFamilyRisk(enriched, userId, accessToken)
            if (!isCurrentLoad(generation, userId)) return
            enriched = withTravel(enriched, userId, accessToken)
            applyCurrentLoad(generation, userId, enriched)
        } catch (error: Exception) {
            val offline = isOffline(error)
            if (!applyCurrentLoad(generation, userId, DashboardState(
                status = if (offline) DashboardStatus.OFFLINE else DashboardStatus.ERROR,
            ))) return
            ProductAnalytics.track(
                "dashboard_failed",
                mapOf("offline" to offline.toString()),
            )
            ProductAnalytics.track("forecast_fetch_failed", mapOf("surface" to "dashboard"))
        }
    }

    private fun withHazards(
        base: DashboardState,
        userId: String,
        accessToken: String?,
        profileId: String,
    ): DashboardState {
        return try {
            val raw = apiClient.fetchHazards(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
            )
            val parsed = parseHazards(raw)
            base.copy(
                hazardsOverallLevel = parsed.overallLevel,
                hazardsOverallScore = parsed.overallScore,
                hazardLines = parsed.lines,
            )
        } catch (_: Exception) {
            base
        }
    }

    private fun withFamilyRisk(
        base: DashboardState,
        userId: String,
        accessToken: String?,
    ): DashboardState {
        return try {
            val raw = apiClient.fetchFamilyRiskOverview(userId, accessToken)
            val members = FamilyRiskParser.parseOverview(raw)
            val highest = JSONObject(raw).optString("highestRiskLevel").takeIf { it.isNotBlank() }
            base.copy(
                familyRiskLines = members,
                familyHighestRisk = highest,
            )
        } catch (_: Exception) {
            base
        }
    }

    private fun withWearable(base: DashboardState, userId: String, accessToken: String?, generation: Long): DashboardState {
        return try {
            val wearableJson = JSONObject(apiClient.fetchWearableToday(userId, accessToken))
            val daily = wearableJson.optJSONObject("dailySummary")
            val steps = if (daily != null && !daily.isNull("stepsTotal")) daily.optInt("stepsTotal") else null
            val load = wearableJson.optJSONObject("personalLoad")
            val loadLevel = load?.optString("level")?.takeIf { it.isNotBlank() }
            val summary = load?.optJSONArray("explanations")
                ?.takeIf { it.length() > 0 }
                ?.optString(0)
                ?.takeIf { it.isNotBlank() }
            val connected = wearableJson.optJSONObject("consent")?.optBoolean("isActive") == true
            val healthSummaryRaw = if (connected && isCurrentLoad(generation, userId)) {
                runCatching {
                    apiClient.fetchHealthSummary(userId, accessToken)
                }.getOrNull()
            } else {
                null
            }
            base.copy(
                wearableSteps = steps,
                wearableLoadLevel = loadLevel,
                wearableSummary = summary,
                wearableConnected = connected,
                healthSummaryRaw = healthSummaryRaw,
            )
        } catch (_: Exception) {
            // Wearable data is optional; the dashboard remains valid without it.
            base
        }
    }

    private fun isOffline(error: Throwable): Boolean {
        return when (error) {
            is UnknownHostException,
            is ConnectException,
            is SocketTimeoutException,
            is SocketException,
            is IOException -> true
            else -> false
        }
    }


    private fun withTravel(
        base: DashboardState,
        userId: String,
        accessToken: String?,
    ): DashboardState {
        return try {
            val session = SettingsViewModel.parseTravelSession(
                apiClient.getTravelSession(userId, accessToken),
            )
            if (!session.active) base
            else base.copy(
                travelActive = true,
                travelPlaceName = session.placeName,
            )
        } catch (_: Exception) {
            base
        }
    }

    companion object {
        fun parseCurrentRisk(raw: String, preferredLanguage: String): DashboardState {
            val json = JSONObject(raw)
            val risk = json.optJSONObject("risk")
                ?: throw IllegalStateException("current-risk response missing 'risk'")
            val level = risk.optString("overallRisk", "")
            if (level.isBlank()) {
                throw IllegalStateException("current-risk response missing 'overallRisk'")
            }
            val recommendation = json.optJSONObject("recommendation")
            val environment = json.optJSONObject("environmental")
            val timezone = environment?.optString("timezone")?.takeIf { it.isNotBlank() }
            val zoneId = HiAirHumanDate.zoneId(timezone)
            val freshness = json.optString("freshness").takeIf { it.isNotBlank() }
                ?: environment?.optString("source")?.takeIf { it.isNotBlank() }
            val dataQuality = json.optString("dataQuality").takeIf { it.isNotBlank() }

            val actions = mutableListOf<String>()
            recommendation?.optJSONArray("actions")?.let { array ->
                for (index in 0 until array.length()) {
                    array.optString(index).takeIf { it.isNotBlank() }?.let(actions::add)
                }
            }

            val safeWindows = mutableListOf<String>()
            risk.optJSONArray("safeWindows")?.let { array ->
                for (index in 0 until array.length()) {
                    val window = array.optJSONObject(index) ?: continue
                    val type = window.optString("type")
                    val start = window.optString("start")
                    val end = window.optString("end")
                    if (start.isNotBlank() && end.isNotBlank()) {
                        safeWindows.add(formatSafeWindow(type, start, end, preferredLanguage, zoneId))
                    }
                }
            }
            // Additive ventilation list — keep labeled separately from outdoor windows.
            risk.optJSONArray("ventilationWindows")?.let { array ->
                for (index in 0 until array.length()) {
                    val window = array.optJSONObject(index) ?: continue
                    val start = window.optString("start")
                    val end = window.optString("end")
                    if (start.isNotBlank() && end.isNotBlank()) {
                        safeWindows.add(
                            formatSafeWindow(
                                type = window.optString("type", "ventilation"),
                                start = start,
                                end = end,
                                preferredLanguage = preferredLanguage,
                                zoneId = zoneId,
                            )
                        )
                    }
                }
            }

            return DashboardState(
                status = DashboardStatus.SUCCESS,
                riskLevel = level,
                riskScore = scoreForLevel(level),
                headline = recommendation?.optString("headline")?.takeIf { it.isNotBlank() },
                explanation = json.optString("explanation").takeIf { it.isNotBlank() },
                actions = actions,
                safeWindows = safeWindows,
                dataSource = environment?.optString("source")?.takeIf { it.isNotBlank() },
                aqi = environment.optionalInt("aqi"),
                pm25 = environment.optionalDouble("pm25"),
                ozone = environment.optionalDouble("ozone"),
                no2 = environment.optionalDouble("no2"),
                temperatureC = environment.optionalDouble("temperature"),
                feelsLikeC = environment.optionalDouble("feels_like"),
                humidityPercent = environment.optionalDouble("humidity"),
                freshness = freshness,
                dataQuality = dataQuality,
                timezone = timezone,
            )
        }

        data class ParsedHazards(
            val overallLevel: String,
            val overallScore: Int,
            val lines: List<HazardLine>,
        )

        fun parseHazards(raw: String): ParsedHazards {
            val json = JSONObject(raw)
            val assessment = json.optJSONObject("assessment")
                ?: throw IllegalStateException("hazards response missing 'assessment'")
            val overallLevel = assessment.optString("overallLevel", "")
            if (overallLevel.isBlank()) {
                throw IllegalStateException("hazards response missing 'overallLevel'")
            }
            val lines = mutableListOf<HazardLine>()
            assessment.optJSONArray("hazards")?.let { array ->
                for (index in 0 until array.length()) {
                    val row = array.getJSONObject(index)
                    lines.add(
                        HazardLine(
                            hazard = row.optString("hazard"),
                            level = row.optString("level"),
                            score = row.optInt("score", 0),
                            available = row.optBoolean("available", false),
                        ),
                    )
                }
            }
            return ParsedHazards(
                overallLevel = overallLevel,
                overallScore = assessment.optInt("overallScore", 0),
                lines = lines,
            )
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
            val label = AndroidL10n.t(typeKey, preferredLanguage)
            val range = HiAirHumanDate.timeRangeIso(start, end, Locale.getDefault(), "", zoneId)
            return if (range.isEmpty()) label else "$label: $range"
        }

        /**
         * Canonical numeric encoding of the backend risk level, matching the
         * server's RISK_LEVEL_TO_SCORE mapping. This is a deterministic visual
         * representation of the real categorical risk, not synthetic data.
         */
        fun scoreForLevel(level: String): Int {
            return when (level.lowercase()) {
                "low" -> 20
                "moderate", "medium" -> 45
                "high" -> 70
                "very_high", "very high" -> 90
                else -> 45
            }
        }

        fun isElevatedRisk(level: String?): Boolean {
            val normalized = level?.lowercase()?.replace(' ', '_') ?: return false
            return normalized == "high" || normalized == "very_high"
        }
    }

    fun markExposureReduced(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        recordProtectedDayEvent(
            userId, accessToken, profileId, preferredLanguage,
            "poor_air_exposure_reduced",
            "dashboard.protected.exposure_done",
        ) { marked, status ->
            state = state.copy(exposureReducedMarked = marked, protectedDayStatus = status)
        }
    }

    fun markHighRiskAvoided(userId: String, accessToken: String?, profileId: String, preferredLanguage: String) {
        recordProtectedDayEvent(
            userId, accessToken, profileId, preferredLanguage,
            "high_risk_period_avoided",
            "dashboard.protected.risk_avoided_done",
        ) { marked, status ->
            state = state.copy(highRiskAvoidedMarked = marked, protectedDayStatus = status)
        }
    }

    private fun recordProtectedDayEvent(
        userId: String,
        accessToken: String?,
        profileId: String,
        preferredLanguage: String,
        eventType: String,
        successKey: String,
        onResult: (marked: Boolean, status: String) -> Unit,
    ) {
        if (userId.isBlank() || profileId.isBlank()) return
        try {
            apiClient.createProtectedDayEvent(
                userId = userId,
                accessToken = accessToken,
                profileId = profileId,
                eventType = eventType,
            )
            onResult(true, AndroidL10n.t(successKey, preferredLanguage))
        } catch (_: Exception) {
            onResult(false, AndroidL10n.t("planner.activity.mark_planned_failed", preferredLanguage))
        }
    }
}

private fun JSONObject?.optionalInt(key: String): Int? {
    if (this == null || !has(key) || isNull(key)) return null
    return optInt(key)
}

private fun JSONObject?.optionalDouble(key: String): Double? {
    if (this == null || !has(key) || isNull(key)) return null
    return optDouble(key)
}
