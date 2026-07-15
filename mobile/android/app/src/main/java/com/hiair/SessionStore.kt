package com.hiair

import android.content.Context

data class StoredSession(
    val email: String = "",
    val userId: String = "",
    val accessToken: String = "",
    val onboardingCompleted: Boolean = false,
    val isGuest: Boolean = false,
    val persona: String = "adult",
    val sensitivityLevel: String = "medium",
    val profileId: String = "",
    val homeLat: Double = 41.39,
    val homeLon: Double = 2.17,
    val preferredLanguage: String = "ru",
    val healthOptIn: Boolean = false,
    val locationGranted: Boolean = false,
    val notificationsGranted: Boolean = false,
)

class SessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("hiair_session", Context.MODE_PRIVATE)

    fun load(): StoredSession {
        return StoredSession(
            email = prefs.getString("email", "") ?: "",
            userId = prefs.getString("user_id", "") ?: "",
            accessToken = prefs.getString("access_token", "") ?: "",
            onboardingCompleted = prefs.getBoolean("onboarding_completed", false),
            isGuest = prefs.getBoolean("is_guest", false),
            persona = prefs.getString("persona", "adult") ?: "adult",
            sensitivityLevel = prefs.getString("sensitivity_level", "medium") ?: "medium",
            profileId = prefs.getString("profile_id", "") ?: "",
            homeLat = prefs.getFloat("home_lat", 41.39f).toDouble(),
            homeLon = prefs.getFloat("home_lon", 2.17f).toDouble(),
            preferredLanguage = prefs.getString("preferred_language", "ru") ?: "ru",
            healthOptIn = prefs.getBoolean("health_opt_in", false),
            locationGranted = prefs.getBoolean("location_granted", false),
            notificationsGranted = prefs.getBoolean("notifications_granted", false),
        )
    }

    fun save(session: StoredSession) {
        prefs.edit()
            .putString("email", session.email)
            .putString("user_id", session.userId)
            .putString("access_token", session.accessToken)
            .putBoolean("onboarding_completed", session.onboardingCompleted)
            .putBoolean("is_guest", session.isGuest)
            .putString("persona", session.persona)
            .putString("sensitivity_level", session.sensitivityLevel)
            .putString("profile_id", session.profileId)
            .putFloat("home_lat", session.homeLat.toFloat())
            .putFloat("home_lon", session.homeLon.toFloat())
            .putString("preferred_language", session.preferredLanguage)
            .putBoolean("health_opt_in", session.healthOptIn)
            .putBoolean("location_granted", session.locationGranted)
            .putBoolean("notifications_granted", session.notificationsGranted)
            .apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
