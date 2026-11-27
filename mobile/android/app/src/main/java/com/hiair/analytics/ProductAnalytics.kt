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

    /** In-memory override for JVM unit tests (no Android prefs). */
    @Volatile
    var analyticsConsentGranted: Boolean = false
        private set

    fun bind(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        analyticsConsentGranted = prefs?.getBoolean(CONSENT_KEY, false) ?: false
    }

    fun setAnalyticsConsent(granted: Boolean) {
        analyticsConsentGranted = granted
        prefs?.edit()?.putBoolean(CONSENT_KEY, granted)?.apply()
    }

    fun trackRoadmapEvent(name: String, properties: Map<String, String> = emptyMap()) {
        if (!analyticsConsentGranted) return
        track(name, properties)
    }

    fun recordAppOpen(surface: String = "dashboard") {
        if (!analyticsConsentGranted) return
        val day = LocalDate.now(ZoneOffset.UTC).toString()
        val store = prefs
        val first = store?.getString(FIRST_OPEN_DAY_KEY, null)
        if (first == null) {
            store?.edit()
                ?.putString(FIRST_OPEN_DAY_KEY, day)
                ?.putString(LAST_OPEN_DAY_KEY, day)
                ?.apply()
            return
        }
        val last = store?.getString(LAST_OPEN_DAY_KEY, null)
        if (last == day) return
        store?.edit()?.putString(LAST_OPEN_DAY_KEY, day)?.apply()
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
        val store = prefs
        if (store?.getBoolean(FIRST_USEFUL_SENT_KEY, false) == true) return
        store?.edit()?.putBoolean(FIRST_USEFUL_SENT_KEY, true)?.apply()
        trackRoadmapEvent(Event.FIRST_USEFUL_RECOMMENDATION, mapOf("surface" to surface))
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
