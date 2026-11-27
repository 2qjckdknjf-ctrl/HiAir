package com.hiair.analytics

import android.util.Log

/** Lightweight product analytics (no third-party SDK, no PII). */
object ProductAnalytics {
    private const val TAG = "HiAirProduct"

    object Event {
        const val APP_STORE_CLICK = "app_store_click"
        const val FIRST_USEFUL_RECOMMENDATION = "first_useful_recommendation"
        const val REPEAT_USE = "repeat_use"
        const val RETENTION_WINDOW = "retention_window"
    }

    @Volatile
    var analyticsConsentGranted: Boolean = false

    fun trackRoadmapEvent(name: String, properties: Map<String, String> = emptyMap()) {
        if (!analyticsConsentGranted) return
        track(name, properties)
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
