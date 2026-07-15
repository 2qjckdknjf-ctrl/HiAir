package com.hiair.analytics

import android.content.Context
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object AnalyticsEvents {
    const val ONBOARDING_STARTED = "onboarding_started"
    const val ONBOARDING_COMPLETED = "onboarding_completed"
    const val DASHBOARD_OPENED = "dashboard_opened"
    const val MORNING_BRIEFING_OPENED = "morning_briefing_opened"
    const val SHARE_CARD_CLICKED = "share_card_clicked"
    const val SYMPTOM_LOGGED = "symptom_logged"
    const val PRIVACY_EXPORT_REQUESTED = "privacy_export_requested"
    const val PRIVACY_DELETE_REQUESTED = "privacy_delete_requested"
    const val GUEST_MODE_USED = "guest_mode_used"
    const val FEEDBACK_SUBMITTED = "feedback_submitted"
    const val APP_INSTALL_TRACKED = "app_install_tracked"
}

class AnalyticsTracker(
    context: Context,
    private val apiClient: ApiClient = ApiClient(AppConfig.apiBaseUrl)
) {
    private val prefs = context.getSharedPreferences("hiair_analytics", Context.MODE_PRIVATE)
    private val sessionId: String = prefs.getString("session_id", null) ?: UUID.randomUUID().toString().also {
        prefs.edit().putString("session_id", it).apply()
    }

    fun track(
        eventName: String,
        userId: String? = null,
        accessToken: String? = null,
        platform: String = "android",
        appVersion: String = "0.1.0",
        properties: Map<String, String> = emptyMap()
    ) {
        Thread {
            try {
                val event = JSONObject().apply {
                    put("session_id", sessionId)
                    put("event_name", eventName)
                    put("platform", platform)
                    put("app_version", appVersion)
                    put("properties", JSONObject(properties))
                }
                apiClient.ingestAnalyticsEvents(
                    userId = userId,
                    accessToken = accessToken,
                    events = JSONArray().put(event)
                )
            } catch (_: Exception) {
                // Analytics must never break user flows.
            }
        }.start()
    }

    fun currentSessionId(): String = sessionId
}
