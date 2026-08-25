package com.hiair.location

import android.location.Location

object GeoCoordinates {
    const val MAX_AGE_MS = 300_000L
    const val LAUNCH_CACHE_MAX_AGE_MS = 1_800_000L
    const val MAX_HORIZONTAL_ACCURACY_METERS = 5000f

    fun isValid(lat: Double, lon: Double): Boolean {
        if (lat !in -90.0..90.0 || lon !in -180.0..180.0) {
            return false
        }
        if (lat == 0.0 && lon == 0.0) {
            return false
        }
        return true
    }

    fun isValid(location: Location, maxAgeMs: Long = MAX_AGE_MS): Boolean {
        if (!isValid(location.latitude, location.longitude)) {
            return false
        }
        if (location.accuracy < 0 || location.accuracy > MAX_HORIZONTAL_ACCURACY_METERS) {
            return false
        }
        if (System.currentTimeMillis() - location.time > maxAgeMs) {
            return false
        }
        return true
    }

    fun isUsableForLaunch(location: Location): Boolean {
        return isValid(location, LAUNCH_CACHE_MAX_AGE_MS)
    }

    fun accuracyBucket(location: Location): String {
        return when {
            location.accuracy < 50f -> "high"
            location.accuracy < 500f -> "medium"
            else -> "low"
        }
    }
}

enum class LocationSource(val raw: String) {
    DEVICE("device"),
    MANUAL("manual"),
    CACHED("cached"),
    UNKNOWN("unknown"),
}
