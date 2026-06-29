package com.hiair.analytics

import android.util.Log

/** Lightweight product analytics (no third-party SDK, no PII). */
object ProductAnalytics {
    private const val TAG = "HiAirProduct"

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
        Log.i(TAG, payload)
    }
}
