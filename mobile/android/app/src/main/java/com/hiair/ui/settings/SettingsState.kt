package com.hiair.ui.settings

import com.hiair.analytics.ProductAnalytics
import com.hiair.location.GeoCoordinates
import com.hiair.location.LocationSource
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import com.hiair.network.ApiHttpException
import com.hiair.network.SupabaseAuthService
import com.hiair.billing.SubscriptionEntitlementParser
import com.hiair.ui.i18n.AndroidL10n
import java.net.ConnectException
import java.net.SocketException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import com.hiair.ui.family.FamilyMemberItem
import com.hiair.ui.family.FamilyMembersParser
import com.hiair.ui.family.FamilyMemberRiskItem
import com.hiair.ui.family.FamilyRiskParser
import com.hiair.ui.work.WorkSiteRiskParser
import org.json.JSONArray
import org.json.JSONObject

data class SavedPlaceItem(
    val id: String,
    val name: String,
    val placeType: String,
    val lat: Double,
    val lon: Double,
    val timezone: String? = null,
)

data class TravelSessionItem(
    val active: Boolean = false,
    val placeId: String? = null,
    val placeName: String? = null,
    val lat: Double? = null,
    val lon: Double? = null,
    val timezone: String? = null,
    val until: String? = null,
    val source: String = "home",
)

data class SettingsState(
    val email: String = "",
    val password: String = "",
    val userId: String = "",
    val accessToken: String = "",
    val refreshToken: String = "",
    val profileId: String = "",
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
    val isPremium: Boolean = false,
    val showPaywall: Boolean = false,
    val paywallStatusText: String = "",
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
    val privacyExportSummary: String = "-",
    val wearableStatus: String = "-",
    val loading: Boolean = false,
    val statusText: String = "-",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    val locationSource: String = LocationSource.UNKNOWN.raw,
    val locationRevision: Int = 0,
    val savedPlaces: List<SavedPlaceItem> = emptyList(),
    val placesStatusText: String = "-",
    val placesLoading: Boolean = false,
    val travelSession: TravelSessionItem = TravelSessionItem(),
    val selectedTravelPlaceId: String = "",
    val travelStatusText: String = "",
    val travelLoading: Boolean = false,
    val workWorkload: String = "moderate",
    val workSiteRiskText: String = "",
    val workSiteRiskProxyOnly: Boolean = false,
    val workSiteRiskLoading: Boolean = false,
    val familyMembers: List<FamilyMemberItem> = emptyList(),
    val familyRiskByLinkId: Map<String, FamilyMemberRiskItem> = emptyMap(),
    val familyStatusText: String = "",
    val availableProfileIds: List<Pair<String, String>> = emptyList(),
)

class SettingsViewModel(
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    private var supabaseAuthService: SupabaseAuthService? = null
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

    fun setRefreshToken(value: String) {
        state = state.copy(refreshToken = value)
    }

    fun setProfileId(value: String) {
        state = state.copy(profileId = value)
    }

    fun hasValidLocation(): Boolean = GeoCoordinates.isValid(state.latitude, state.longitude)

    fun applyDeviceLocation(lat: Double, lon: Double): Boolean {
        if (!GeoCoordinates.isValid(lat, lon)) {
            return false
        }
        state = state.copy(
            latitude = lat,
            longitude = lon,
            locationSource = LocationSource.DEVICE.raw,
            locationRevision = state.locationRevision + 1,
        )
        // New users still need ensure before data fetch; existing profiles sync in background.
        if (state.profileId.isBlank()) {
            return syncProfileLocationIfNeeded()
        }
        Thread {
            syncProfileLocationIfNeeded()
        }.start()
        return true
    }

    fun hydrateProfileLocation(profileJson: JSONObject) {
        val lat = profileJson.optDouble("home_lat", 0.0)
        val lon = profileJson.optDouble("home_lon", 0.0)
        if (!GeoCoordinates.isValid(lat, lon)) {
            return
        }
        if (state.locationSource == LocationSource.DEVICE.raw && hasValidLocation()) {
            return
        }
        state = state.copy(
            latitude = lat,
            longitude = lon,
            locationSource = LocationSource.CACHED.raw,
            locationRevision = state.locationRevision + 1,
        )
    }

    fun syncProfileLocationIfNeeded(): Boolean {
        if (!hasValidLocation() || state.userId.isBlank() || state.accessToken.isBlank()) {
            return false
        }
        if (state.profileId.isBlank()) {
            return ensureProfile() != null
        }
        return try {
            apiClient.updateProfileLocation(
                userId = state.userId,
                accessToken = state.accessToken,
                profileId = state.profileId,
                homeLat = state.latitude,
                homeLon = state.longitude,
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Resolves the active personalization profile. Creates one only when valid
     * device coordinates are available — never with null island (0,0).
     */
    fun ensureProfile(): String? {
        if (state.profileId.isNotBlank()) {
            return state.profileId
        }
        val current = state
        if (current.userId.isBlank() || current.accessToken.isBlank()) {
            return null
        }
        return try {
            val token = current.accessToken.ifBlank { null }
            val profilesRaw = apiClient.listProfiles(current.userId, token)
            val array = JSONArray(profilesRaw)
            if (array.length() > 0) {
                val profile = array.getJSONObject(0)
                val resolved = profile.optString("id").takeIf { it.isNotBlank() }
                if (resolved.isNullOrBlank()) {
                    null
                } else {
                    hydrateProfileLocation(profile)
                    state = state.copy(profileId = resolved)
                    resolved
                }
            } else {
                if (!hasValidLocation()) {
                    return null
                }
                val resolved = parseProfileId(
                    apiClient.createProfile(
                        userId = current.userId,
                        accessToken = token,
                        personaType = current.defaultPersona,
                        sensitivityLevel = "medium",
                        homeLat = state.latitude,
                        homeLon = state.longitude,
                    )
                )
                if (resolved.isNullOrBlank()) {
                    null
                } else {
                    state = state.copy(profileId = resolved, locationRevision = state.locationRevision + 1)
                    resolved
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun parseFirstProfileId(raw: String): String? {
        val array = JSONArray(raw)
        if (array.length() == 0) {
            return null
        }
        return array.optJSONObject(0)?.optString("id")?.takeIf { it.isNotBlank() }
    }

    private fun parseProfileId(raw: String): String? {
        return JSONObject(raw).optString("id").takeIf { it.isNotBlank() }
    }

    fun configureSupabaseAuth(authService: SupabaseAuthService) {
        supabaseAuthService = authService
    }

    fun notifySessionExpired() {
        state = state.copy(statusText = l("settings.auth_expired"))
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
        val lower = value.lowercase()
        val normalized = when {
            lower.startsWith("fr") -> "fr"
            lower.startsWith("it") -> "it"
            lower.startsWith("es") -> "es"
            lower.startsWith("en") -> "en"
            else -> "ru"
        }
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

    private fun meetsSignupPasswordPolicy(password: String): Boolean {
        if (password.length < 12) return false
        if (!password.any { it.isUpperCase() }) return false
        if (!password.any { it.isLowerCase() }) return false
        if (!password.any { it.isDigit() }) return false
        if (!password.any { !it.isLetterOrDigit() }) return false
        return true
    }

    fun signup(onComplete: (() -> Unit)? = null) {
        if (state.email.isBlank() || !meetsSignupPasswordPolicy(state.password)) {
            state = state.copy(statusText = l("settings.valid_credentials_required"))
            onComplete?.invoke()
            return
        }
        state = state.copy(loading = true)
        try {
            val session = supabaseAuthService?.signUp(state.email, state.password)
                ?: run {
                    val json = JSONObject(apiClient.signup(state.email, state.password))
                    com.hiair.network.SupabaseSession(
                        userId = json.getString("user_id"),
                        email = state.email,
                        accessToken = json.getString("access_token"),
                        refreshToken = json.optString("refresh_token", ""),
                    )
                }
            state = state.copy(
                loading = false,
                userId = session.userId,
                accessToken = session.accessToken,
                refreshToken = session.refreshToken,
                statusText = l("settings.signed_up")
            )
            refreshEntitlement(onComplete)
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.signup_failed"))
            onComplete?.invoke()
        }
    }

    fun login(onComplete: (() -> Unit)? = null) {
        if (state.email.isBlank() || state.password.length < 12) {
            state = state.copy(statusText = l("settings.valid_credentials_required"))
            onComplete?.invoke()
            return
        }
        state = state.copy(loading = true)
        try {
            val session = supabaseAuthService?.signIn(state.email, state.password)
                ?: run {
                    val json = JSONObject(apiClient.login(state.email, state.password))
                    com.hiair.network.SupabaseSession(
                        userId = json.getString("user_id"),
                        email = state.email,
                        accessToken = json.getString("access_token"),
                        refreshToken = json.optString("refresh_token", ""),
                    )
                }
            state = state.copy(
                loading = false,
                userId = session.userId,
                accessToken = session.accessToken,
                refreshToken = session.refreshToken,
                statusText = l("settings.logged_in")
            )
            refreshEntitlement(onComplete)
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.login_failed"))
            onComplete?.invoke()
        }
    }

    fun launchGoogleOAuth() {
        supabaseAuthService?.launchGoogleSignIn()
    }

    fun launchAppleOAuth() {
        supabaseAuthService?.launchAppleSignIn()
    }

    fun signOutSupabase() {
        try {
            supabaseAuthService?.signOut()
        } catch (_: Exception) {
            // no-op
        }
    }

    fun clearEntitlementState() {
        state = state.copy(
            isPremium = false,
            subscriptionStatus = "inactive",
            showPaywall = false,
            paywallStatusText = "",
        )
    }

    fun resetSessionAfterLogout() {
        signOutSupabase()
        state = state.copy(
            userId = "",
            email = "",
            accessToken = "",
            refreshToken = "",
            profileId = "",
            password = "",
            isPremium = false,
            subscriptionStatus = "inactive",
            showPaywall = false,
            paywallStatusText = "",
        )
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
            ProductAnalytics.track(
                "morning_briefing_viewed",
                mapOf("enabled" to briefing.optBoolean("enabled", false).toString())
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

    fun exportPrivacyData() {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(loading = true)
        try {
            val json = JSONObject(apiClient.fetchPrivacyExport(state.userId, state.accessToken))
            val sectionCount = json.optJSONObject("data")?.length() ?: 0
            state = state.copy(
                loading = false,
                privacyExportSummary = "${l("settings.privacy_export_ready")}: $sectionCount",
                statusText = l("settings.privacy_export_done")
            )
            ProductAnalytics.track("privacy_export")
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.privacy_export_failed"))
        }
    }

    fun deleteAccount(): Boolean {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            return false
        }
        state = state.copy(loading = true)
        return try {
            apiClient.deleteAccount(state.userId, state.accessToken)
            state = state.copy(
                loading = false,
                email = "",
                password = "",
                userId = "",
                accessToken = "",
                refreshToken = "",
                privacyExportSummary = "-",
                statusText = l("settings.account_deleted")
            )
            ProductAnalytics.track("privacy_delete")
            true
        } catch (_: Exception) {
            state = state.copy(loading = false, statusText = l("settings.account_delete_failed"))
            false
        }
    }

    fun loadPlaces() {
        if (state.userId.isBlank()) {
            state = state.copy(placesStatusText = l("settings.user_id_required"))
            return
        }
        state = state.copy(placesLoading = true)
        try {
            val raw = apiClient.listPlaces(state.userId, state.accessToken.ifBlank { null })
            val places = parsePlacesList(raw)
            val selected = when {
                state.selectedTravelPlaceId.isNotBlank() && places.any { it.id == state.selectedTravelPlaceId } ->
                    state.selectedTravelPlaceId
                else -> places.firstOrNull()?.id.orEmpty()
            }
            state = state.copy(
                placesLoading = false,
                savedPlaces = places,
                selectedTravelPlaceId = selected,
                placesStatusText = l("places.loaded"),
            )
        } catch (_: Exception) {
            state = state.copy(placesLoading = false, placesStatusText = l("places.load_failed"))
        }
    }

    fun loadTravelSession() {
        if (state.userId.isBlank()) return
        try {
            val session = parseTravelSession(apiClient.getTravelSession(state.userId, state.accessToken.ifBlank { null }))
            state = state.copy(
                travelSession = session,
                selectedTravelPlaceId = session.placeId?.takeIf { it.isNotBlank() }
                    ?: state.selectedTravelPlaceId,
                travelStatusText = "",
            )
        } catch (_: Exception) {
            state = state.copy(travelStatusText = l("settings.travel.load_failed"))
        }
    }

    fun setSelectedTravelPlaceId(placeId: String) {
        state = state.copy(selectedTravelPlaceId = placeId)
    }

    fun startTravel(placeId: String = state.selectedTravelPlaceId) {
        if (state.userId.isBlank()) return
        if (placeId.isBlank()) {
            state = state.copy(travelStatusText = l("settings.travel.need_place"))
            return
        }
        state = state.copy(travelLoading = true)
        try {
            val session = parseTravelSession(
                apiClient.startTravelSession(
                    userId = state.userId,
                    accessToken = state.accessToken.ifBlank { null },
                    placeId = placeId,
                ),
            )
            state = state.copy(
                travelLoading = false,
                travelSession = session,
                selectedTravelPlaceId = placeId,
                travelStatusText = l("settings.travel.started"),
            )
        } catch (_: Exception) {
            state = state.copy(
                travelLoading = false,
                travelStatusText = l("settings.travel.start_failed"),
            )
        }
    }

    fun endTravel() {
        if (state.userId.isBlank()) return
        state = state.copy(travelLoading = true)
        try {
            val session = parseTravelSession(
                apiClient.clearTravelSession(state.userId, state.accessToken.ifBlank { null }),
            )
            state = state.copy(
                travelLoading = false,
                travelSession = session,
                travelStatusText = l("settings.travel.ended"),
            )
        } catch (_: Exception) {
            state = state.copy(
                travelLoading = false,
                travelStatusText = l("settings.travel.end_failed"),
            )
        }
    }

    fun setWorkWorkload(workload: String) {
        state = state.copy(workWorkload = workload)
    }

    fun loadWorkSiteRisk() {
        if (state.userId.isBlank()) {
            state = state.copy(workSiteRiskText = l("settings.work.no_location"))
            return
        }
        if (!hasValidLocation()) {
            state = state.copy(workSiteRiskText = l("settings.work.no_location"))
            return
        }
        state = state.copy(workSiteRiskLoading = true, workSiteRiskText = "")
        try {
            val raw = apiClient.fetchSiteRisk(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                lat = state.latitude,
                lon = state.longitude,
                workload = state.workWorkload,
                acclimatized = true,
            )
            val parsed = WorkSiteRiskParser.parse(raw, state.preferredLanguage)
            state = state.copy(
                workSiteRiskLoading = false,
                workSiteRiskText = parsed.summaryLine,
                workSiteRiskProxyOnly = parsed.proxyOnly,
            )
        } catch (_: Exception) {
            state = state.copy(
                workSiteRiskLoading = false,
                workSiteRiskText = l("settings.work.load_failed"),
                workSiteRiskProxyOnly = false,
            )
        }
    }

    fun refreshAvailableProfiles() {
        if (state.userId.isBlank()) return
        try {
            val array = JSONArray(apiClient.listProfiles(state.userId, state.accessToken.ifBlank { null }))
            val profiles = buildList {
                for (index in 0 until array.length()) {
                    val profile = array.getJSONObject(index)
                    val id = profile.optString("id")
                    val persona = profile.optString("persona_type", "adult")
                    if (id.isNotBlank()) add(id to persona)
                }
            }
            state = state.copy(availableProfileIds = profiles)
        } catch (_: Exception) {
            // Optional enrichment for family UI.
        }
    }

    fun loadFamilyMembers() {
        if (state.userId.isBlank()) return
        try {
            val raw = apiClient.listFamilyMembers(state.userId, state.accessToken.ifBlank { null })
            state = state.copy(
                familyMembers = FamilyMembersParser.parseList(raw),
                familyStatusText = "",
            )
            loadFamilyRiskOverview()
        } catch (_: Exception) {
            state = state.copy(familyStatusText = l("settings.family.load_failed"))
        }
    }

    fun loadFamilyRiskOverview() {
        if (state.userId.isBlank()) return
        try {
            val raw = apiClient.fetchFamilyRiskOverview(state.userId, state.accessToken.ifBlank { null })
            val risks = FamilyRiskParser.parseOverview(raw)
            state = state.copy(
                familyRiskByLinkId = risks.associateBy { it.memberLinkId },
            )
        } catch (_: Exception) {
            state = state.copy(familyRiskByLinkId = emptyMap())
        }
    }

    fun addFamilyMember(profileId: String, relation: String, label: String?) {
        if (state.userId.isBlank() || profileId.isBlank()) return
        try {
            val raw = apiClient.createFamilyMember(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                memberProfileId = profileId,
                relation = relation,
                label = label,
            )
            val created = FamilyMembersParser.parseMember(raw)
            state = state.copy(
                familyMembers = state.familyMembers + created,
                familyStatusText = l("settings.family.added"),
            )
        } catch (_: Exception) {
            state = state.copy(familyStatusText = l("settings.family.add_failed"))
        }
    }

    fun deleteFamilyMember(linkId: String) {
        if (state.userId.isBlank() || linkId.isBlank()) return
        try {
            apiClient.deleteFamilyMember(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                memberLinkId = linkId,
            )
            state = state.copy(
                familyMembers = state.familyMembers.filterNot { it.id == linkId },
                familyStatusText = l("settings.family.deleted"),
            )
        } catch (_: Exception) {
            state = state.copy(familyStatusText = l("settings.family.delete_failed"))
        }
    }

    fun addSavedPlace(name: String, placeType: String) {
        if (state.userId.isBlank()) {
            state = state.copy(placesStatusText = l("settings.user_id_required"))
            return
        }
        val trimmedName = name.trim()
        if (trimmedName.isBlank()) {
            state = state.copy(placesStatusText = l("places.name_required"))
            return
        }
        if (!hasValidLocation()) {
            state = state.copy(placesStatusText = l("places.location_required"))
            return
        }
        state = state.copy(placesLoading = true)
        try {
            val raw = apiClient.createPlace(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                name = trimmedName,
                placeType = placeType,
                lat = state.latitude,
                lon = state.longitude,
            )
            val created = parseSavedPlace(raw)
            state = state.copy(
                placesLoading = false,
                savedPlaces = state.savedPlaces + created,
                placesStatusText = l("places.added"),
            )
        } catch (error: ApiHttpException) {
            state = state.copy(
                placesLoading = false,
                placesStatusText = if (error.statusCode == 402) {
                    l("places.limit_reached")
                } else {
                    l("places.add_failed")
                },
            )
        } catch (_: Exception) {
            state = state.copy(placesLoading = false, placesStatusText = l("places.add_failed"))
        }
    }

    fun deleteSavedPlace(placeId: String) {
        if (state.userId.isBlank() || placeId.isBlank()) {
            return
        }
        state = state.copy(placesLoading = true)
        try {
            apiClient.deletePlace(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                placeId = placeId,
            )
            val remaining = state.savedPlaces.filterNot { it.id == placeId }
            state = state.copy(
                placesLoading = false,
                savedPlaces = remaining,
                selectedTravelPlaceId = when {
                    state.selectedTravelPlaceId == placeId -> remaining.firstOrNull()?.id.orEmpty()
                    else -> state.selectedTravelPlaceId
                },
                placesStatusText = l("places.deleted"),
            )
            loadTravelSession()
        } catch (_: Exception) {
            state = state.copy(placesLoading = false, placesStatusText = l("places.delete_failed"))
        }
    }

    fun refreshWearableStatus() {
        if (state.userId.isBlank()) return
        try {
            val raw = apiClient.fetchWearableToday(state.userId, state.accessToken)
            val json = JSONObject(raw)
            val active = json.optJSONObject("consent")?.optBoolean("isActive") == true
            state = state.copy(
                wearableStatus = if (active) {
                    l("settings.wearables.connected")
                } else {
                    l("wearable.dashboard.not_connected")
                }
            )
        } catch (_: Exception) {
            state = state.copy(wearableStatus = l("wearable.dashboard.not_connected"))
        }
    }

    fun deleteWearableData() {
        if (state.userId.isBlank()) return
        // Prefer host local-first path; this method remains for tests / fallbacks.
        try {
            state = state.copy(statusText = l("settings.wearables.local_stopped"))
            refreshWearableStatus()
        } catch (_: Exception) {
            state = state.copy(statusText = l("settings.privacy_export_failed"))
        }
    }

    fun disconnectWearables() {
        if (state.userId.isBlank()) return
        try {
            state = state.copy(statusText = l("settings.wearables.local_stopped"))
            refreshWearableStatus()
        } catch (_: Exception) {
            state = state.copy(statusText = l("settings.privacy_export_failed"))
        }
    }

    fun applyWearableRevokeResult(remoteCleanupSucceeded: Boolean, deleteData: Boolean) {
        state = state.copy(
            wearableStatus = l("wearable.dashboard.not_connected"),
            statusText = if (remoteCleanupSucceeded) {
                if (deleteData) l("settings.wearables.delete") else l("settings.wearables.disconnected")
            } else {
                l("settings.wearables.remote_cleanup_pending")
            },
        )
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
        refreshEntitlement()
    }

    fun refreshEntitlement(onComplete: (() -> Unit)? = null) {
        if (state.userId.isBlank()) {
            state = state.copy(statusText = l("settings.user_id_required"))
            onComplete?.invoke()
            return
        }
        state = state.copy(loading = true)
        Thread {
            try {
                val raw = apiClient.fetchMySubscription(state.userId, state.accessToken)
                applyEntitlementFromSubscriptionJson(raw)
                val json = JSONObject(raw)
                val planId = if (json.has("plan_id") && !json.isNull("plan_id")) {
                    json.getString("plan_id")
                } else {
                    state.selectedPlanId
                }
                state = state.copy(
                    loading = false,
                    selectedPlanId = planId,
                    subscriptionStatus = json.optString("status", "inactive"),
                    statusText = l("settings.subscription_loaded")
                )
            } catch (_: Exception) {
                state = state.copy(loading = false, statusText = l("settings.subscription_load_failed"))
            }
            onComplete?.invoke()
        }.start()
    }

    fun applyEntitlementFromSubscriptionJson(raw: String) {
        val premium = SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(raw)
        state = state.copy(isPremium = premium)
    }

    fun verifyAndroidPurchase(productId: String, purchaseToken: String, onComplete: ((Boolean) -> Unit)? = null) {
        if (state.userId.isBlank()) {
            state = state.copy(paywallStatusText = l("settings.user_id_required"))
            onComplete?.invoke(false)
            return
        }
        state = state.copy(loading = true, paywallStatusText = l("paywall.verifying"))
        Thread {
            var activated = false
            try {
                val verifyRaw = apiClient.verifyAndroidSubscription(
                    userId = state.userId,
                    productId = productId,
                    purchaseToken = purchaseToken,
                    accessToken = state.accessToken
                )
                applyEntitlementFromSubscriptionJson(verifyRaw)
                if (SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(verifyRaw)) {
                    val json = JSONObject(verifyRaw)
                    activated = true
                    state = state.copy(
                        loading = false,
                        subscriptionStatus = json.optString("status", "active"),
                        paywallStatusText = l("paywall.success"),
                        statusText = l("settings.subscription_activated")
                    )
                    onComplete?.invoke(true)
                    return@Thread
                }
                try {
                    val meRaw = apiClient.fetchMySubscription(state.userId, state.accessToken)
                    applyEntitlementFromSubscriptionJson(meRaw)
                    val json = JSONObject(meRaw)
                    activated = state.isPremium
                    state = state.copy(
                        loading = false,
                        subscriptionStatus = json.optString("status", "active"),
                        paywallStatusText = if (state.isPremium) {
                            l("paywall.success")
                        } else {
                            l("paywall.verify_pending")
                        },
                        statusText = l("settings.subscription_activated")
                    )
                } catch (_: Exception) {
                    state = state.copy(
                        loading = false,
                        paywallStatusText = if (state.isPremium) {
                            l("paywall.success")
                        } else {
                            l("paywall.verify_pending")
                        }
                    )
                }
            } catch (error: ApiHttpException) {
                val message = if (error.statusCode == 503) {
                    l("paywall.android_billing_unavailable")
                } else {
                    l("paywall.verify_failed")
                }
                state = state.copy(
                    loading = false,
                    paywallStatusText = message
                )
            } catch (_: Exception) {
                state = state.copy(
                    loading = false,
                    paywallStatusText = l("paywall.verify_failed")
                )
            }
            onComplete?.invoke(activated)
        }.start()
    }

    fun requestShowPaywall() {
        state = state.copy(showPaywall = true, paywallStatusText = "")
    }

    fun dismissPaywall() {
        state = state.copy(showPaywall = false)
    }

    fun setPaywallStatus(message: String) {
        state = state.copy(paywallStatusText = message)
    }

    fun finalizeRestoreFromStore(onComplete: (() -> Unit)? = null) {
        refreshEntitlement {
            state = state.copy(
                paywallStatusText = if (state.isPremium) {
                    l("paywall.restore_success")
                } else {
                    l("paywall.restore_empty")
                }
            )
            onComplete?.invoke()
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
            val raw = apiClient.activateSubscription(
                userId = state.userId,
                planId = state.selectedPlanId,
                useTrial = true,
                accessToken = state.accessToken
            )
            applyEntitlementFromSubscriptionJson(raw)
            val json = JSONObject(raw)
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
            val raw = apiClient.cancelSubscription(state.userId, state.accessToken)
            applyEntitlementFromSubscriptionJson(raw)
            val json = JSONObject(raw)
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

    companion object {
        fun parsePlacesList(raw: String): List<SavedPlaceItem> {
            val array = JSONObject(raw).optJSONArray("places") ?: JSONArray()
            return buildList {
                for (index in 0 until array.length()) {
                    add(parseSavedPlace(array.getJSONObject(index)))
                }
            }
        }

        fun parseSavedPlace(raw: String): SavedPlaceItem {
            return parseSavedPlace(JSONObject(raw))
        }

        private fun parseSavedPlace(json: JSONObject): SavedPlaceItem {
            return SavedPlaceItem(
                id = json.getString("id"),
                name = json.getString("name"),
                placeType = json.optString("placeType"),
                lat = json.getDouble("lat"),
                lon = json.getDouble("lon"),
                timezone = json.optString("timezone").takeIf { it.isNotBlank() },
            )
        }

        fun parseTravelSession(raw: String): TravelSessionItem {
            val json = JSONObject(raw)
            return TravelSessionItem(
                active = json.optBoolean("active", false),
                placeId = json.optString("placeId").takeIf { it.isNotBlank() },
                placeName = json.optString("placeName").takeIf { it.isNotBlank() },
                lat = if (json.isNull("lat")) null else json.optDouble("lat"),
                lon = if (json.isNull("lon")) null else json.optDouble("lon"),
                timezone = json.optString("timezone").takeIf { it.isNotBlank() },
                until = json.optString("until").takeIf { it.isNotBlank() },
                source = json.optString("source", "home").ifBlank { "home" },
            )
        }
    }
}
