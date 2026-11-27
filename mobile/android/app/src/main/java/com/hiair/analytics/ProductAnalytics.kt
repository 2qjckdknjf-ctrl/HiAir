package com.hiair.analytics

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

/** Lightweight product analytics (no third-party SDK, no PII). */
object ProductAnalytics {
    private const val TAG = "HiAirProduct"
    private const val PREFS = "hiair_product_analytics"
    private const val CONSENT_KEY = "consent"
    private const val FIRST_OPEN_DAY_KEY = "first_open_day"
    private const val LAST_OPEN_DAY_KEY = "last_open_day"
    private const val FIRST_USEFUL_SENT_KEY = "first_useful_sent"

    object Event {
        const val APP_STORE_CLICK = "app_store_click"
        const val FIRST_USEFUL_RECOMMENDATION = "first_useful_recommendation"
        const val REPEAT_USE = "repeat_use"
        const val RETENTION_WINDOW = "retention_window"
    }

    @Volatile
    private var prefs: SharedPreferences? = null

    @Volatile
    private var boundUserId: String = ""

    /** In-memory consent for the bound account (false when logged out). */
    @Volatile
    var analyticsConsentGranted: Boolean = false
        private set

    fun bind(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        discardLegacyGlobalKeys()
        analyticsConsentGranted = readConsent()
    }

    /** Load this account's consent and first-use flags. Does not copy another account. */
    fun bindAccount(userId: String) {
        val trimmed = userId.trim()
        if (trimmed.isEmpty()) {
            clearAccountSession()
            return
        }
        boundUserId = trimmed
        discardLegacyGlobalKeys()
        analyticsConsentGranted = readConsent()
    }

    /** Drop the in-memory binding. Persisted per-account flags stay for that user. */
    fun clearAccountSession() {
        boundUserId = ""
        analyticsConsentGranted = false
        discardLegacyGlobalKeys()
    }

    fun setAnalyticsConsent(granted: Boolean) {
        val key = scopedKey(CONSENT_KEY)
        if (key == null) {
            analyticsConsentGranted = false
            return
        }
        analyticsConsentGranted = granted
        prefs?.edit()?.putBoolean(key, granted)?.commit()
    }

    fun trackRoadmapEvent(name: String, properties: Map<String, String> = emptyMap()) {
        if (!analyticsConsentGranted) return
        track(name, properties)
    }

    fun recordAppOpen(surface: String = "dashboard") {
        if (!analyticsConsentGranted) return
        val firstKey = scopedKey(FIRST_OPEN_DAY_KEY) ?: return
        val lastKey = scopedKey(LAST_OPEN_DAY_KEY) ?: return
        val day = LocalDate.now(ZoneOffset.UTC).toString()
        val store = prefs
        val first = store?.getString(firstKey, null)
        if (first == null) {
            store?.edit()
                ?.putString(firstKey, day)
                ?.putString(lastKey, day)
                ?.apply()
            return
        }
        val last = store?.getString(lastKey, null)
        if (last == day) return
        store?.edit()?.putString(lastKey, day)?.apply()
        trackRoadmapEvent(Event.REPEAT_USE, mapOf("surface" to surface))
        runCatching {
            val firstDate = LocalDate.parse(first)
            val nowDate = LocalDate.parse(day)
            if (ChronoUnit.DAYS.between(firstDate, nowDate) >= 7) {
                trackRoadmapEvent(
                    Event.RETENTION_WINDOW,
                    mapOf("window" to "7d", "surface" to surface),
                )
            }
        }
    }

    fun recordUsefulRecommendation(surface: String) {
        if (!analyticsConsentGranted) return
        val key = scopedKey(FIRST_USEFUL_SENT_KEY) ?: return
        val store = prefs
        if (store?.getBoolean(key, false) == true) return
        store?.edit()?.putBoolean(key, true)?.apply()
        trackRoadmapEvent(Event.FIRST_USEFUL_RECOMMENDATION, mapOf("surface" to surface))
    }

    private fun scopedKey(base: String): String? {
        val userId = boundUserId
        if (userId.isBlank()) return null
        return "$base.$userId"
    }

    private fun readConsent(): Boolean {
        val key = scopedKey(CONSENT_KEY) ?: return false
        return prefs?.getBoolean(key, false) ?: false
    }

    private fun discardLegacyGlobalKeys() {
        val store = prefs ?: return
        store.edit()
            .remove(CONSENT_KEY)
            .remove(FIRST_OPEN_DAY_KEY)
            .remove(LAST_OPEN_DAY_KEY)
            .remove(FIRST_USEFUL_SENT_KEY)
            .apply()
    }

    fun track(name: String, properties: Map<String, String> = emptyMap()) {
        val sanitized = properties.filter { (key, value) ->
            !key.contains("email", ignoreCase = true)
                && !key.contains("token", ignoreCase = true)
                && !key.contains("user", ignoreCase = true)
                && !value.contains("@")
        }
        val payload = if (sanitized.isEmpty()) {
            name
        } else {
            val props = sanitized.entries.sortedBy { it.key }.joinToString(" ") { "${it.key}=${it.value}" }
            "$name $props"
        }
        // Product analytics must never break a user action. Local JVM unit tests do not
        // provide an Android Log implementation, so logging is intentionally best-effort.
        runCatching { Log.i(TAG, payload) }
    }
}
