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

    private var accountId: String? = null
    internal var testEventSink: ((String, Map<String, String>) -> Unit)? = null

    val analyticsConsentGranted: Boolean
        @Synchronized get() = consentGranted()

    @Synchronized
    fun bind(context: Context) {
        prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        accountId = null
    }

    @Synchronized
    fun bindAccount(userId: String?, accessToken: String?) {
        accountId = if (accessToken.isNullOrBlank()) null else userId?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }
    }

    private fun authorizedAccount(userId: String?): String? {
        val owner = accountId ?: return null
        if (userId != null && userId.trim().lowercase() != owner) return null
        return owner
    }

    private fun scopedKey(key: String, owner: String) = "$key.account.$owner"

    @Synchronized
    fun consentGranted(userId: String? = null): Boolean {
        val owner = authorizedAccount(userId) ?: return false
        // Device-wide legacy values cannot prove consent for any account.
        return prefs?.getBoolean(scopedKey(CONSENT_KEY, owner), false) ?: false
    }

    @Synchronized
    fun setAnalyticsConsent(granted: Boolean, userId: String? = null): Boolean {
        val owner = authorizedAccount(userId) ?: return false
        prefs?.edit()?.putBoolean(scopedKey(CONSENT_KEY, owner), granted)?.apply()
        return prefs != null
    }

    @Synchronized
    fun trackRoadmapEvent(name: String, properties: Map<String, String> = emptyMap(), userId: String? = null) {
        if (!consentGranted(userId)) return
        track(name, properties)
    }

    @Synchronized
    fun recordAppOpen(surface: String = "dashboard", userId: String? = null) {
        val owner = authorizedAccount(userId) ?: return
        if (!consentGranted(owner)) return
        val firstOpenKey = scopedKey(FIRST_OPEN_DAY_KEY, owner)
        val lastOpenKey = scopedKey(LAST_OPEN_DAY_KEY, owner)
        val day = LocalDate.now(ZoneOffset.UTC).toString()
        val store = prefs
        val first = store?.getString(firstOpenKey, null)
        if (first == null) {
            store?.edit()
                ?.putString(firstOpenKey, day)
                ?.putString(lastOpenKey, day)
                ?.apply()
            return
        }
        val last = store?.getString(lastOpenKey, null)
        if (last == day) return
        store?.edit()?.putString(lastOpenKey, day)?.apply()
        trackRoadmapEvent(Event.REPEAT_USE, mapOf("surface" to surface), userId = owner)
        runCatching {
            val firstDate = LocalDate.parse(first)
            val nowDate = LocalDate.parse(day)
            if (ChronoUnit.DAYS.between(firstDate, nowDate) >= 7) {
                trackRoadmapEvent(
                    Event.RETENTION_WINDOW,
                    mapOf("window" to "7d", "surface" to surface),
                    userId = owner,
                )
            }
        }
    }

    @Synchronized
    fun recordUsefulRecommendation(surface: String, userId: String? = null) {
        val owner = authorizedAccount(userId) ?: return
        if (!consentGranted(owner)) return
        val store = prefs
        val key = scopedKey(FIRST_USEFUL_SENT_KEY, owner)
        if (store?.getBoolean(key, false) == true) return
        store?.edit()?.putBoolean(key, true)?.apply()
        trackRoadmapEvent(Event.FIRST_USEFUL_RECOMMENDATION, mapOf("surface" to surface), userId = owner)
    }

    fun track(name: String, properties: Map<String, String> = emptyMap()) {
        val sanitized = properties.filter { (key, value) ->
            !key.contains("email", ignoreCase = true)
                && !key.contains("token", ignoreCase = true)
                && !key.contains("user", ignoreCase = true)
                && !value.contains("@")
        }
        testEventSink?.invoke(name, sanitized)
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
