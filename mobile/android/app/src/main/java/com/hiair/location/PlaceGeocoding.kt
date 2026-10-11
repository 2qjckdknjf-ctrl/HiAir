package com.hiair.location

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Pure geocoding helpers — coordinate keys, reuse distance, no Android Geocoder. */
object PlaceGeocoding {
    const val REUSE_DISTANCE_METERS = 1_000.0

    fun coordinateKey(lat: Double, lon: Double): String {
        val roundedLat = String.format(java.util.Locale.US, "%.3f", lat)
        val roundedLon = String.format(java.util.Locale.US, "%.3f", lon)
        return "$roundedLat,$roundedLon"
    }

    fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val earthRadius = 6_371_000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }

    fun canReuse(
        cachedLat: Double,
        cachedLon: Double,
        lat: Double,
        lon: Double,
        maxMeters: Double = REUSE_DISTANCE_METERS,
    ): Boolean {
        if (!GeoCoordinates.isValid(cachedLat, cachedLon) || !GeoCoordinates.isValid(lat, lon)) {
            return false
        }
        return distanceMeters(cachedLat, cachedLon, lat, lon) <= maxMeters
    }
}
