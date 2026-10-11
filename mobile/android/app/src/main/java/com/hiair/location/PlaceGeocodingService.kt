package com.hiair.location

import android.content.Context
import android.location.Geocoder
import android.os.Build
import java.util.Locale
import java.util.concurrent.atomic.AtomicLong

/**
 * Reverse-geocodes coordinates to a locality name.
 * Account-scoped presentation cache; latest-wins; does not invent city names.
 */
class PlaceGeocodingService(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val generation = AtomicLong(0)

    fun bindAccount(userId: String) {
        if (userId.isBlank()) {
            invalidateSession()
            return
        }
        val owner = prefs.getString(KEY_OWNER, "") ?: ""
        if (owner.isNotBlank() && owner != userId) {
            clearPresentation()
        }
        prefs.edit().putString(KEY_OWNER, userId).apply()
    }

    fun invalidateSession() {
        generation.incrementAndGet()
        clearPresentation()
    }

    fun presentationPlaceName(userId: String): String? {
        if (userId.isBlank()) return null
        if (prefs.getString(KEY_OWNER, "") != userId) return null
        return prefs.getString(KEY_NAME, "")?.takeIf { it.isNotBlank() }
    }

    fun reusablePresentationName(userId: String, lat: Double, lon: Double): String? {
        val name = presentationPlaceName(userId) ?: return null
        if (!prefs.contains(KEY_LAT) || !prefs.contains(KEY_LON)) return null
        val priorLat = java.lang.Double.longBitsToDouble(prefs.getLong(KEY_LAT, 0L))
        val priorLon = java.lang.Double.longBitsToDouble(prefs.getLong(KEY_LON, 0L))
        return if (PlaceGeocoding.canReuse(priorLat, priorLon, lat, lon)) name else null
    }

    fun resolveAsync(
        userId: String,
        lat: Double,
        lon: Double,
        onResult: (String?) -> Unit,
    ) {
        if (!GeoCoordinates.isValid(lat, lon)) {
            onResult(null)
            return
        }
        reusablePresentationName(userId, lat, lon)?.let {
            onResult(it)
            return
        }
        val ticket = generation.incrementAndGet()
        Thread {
            val name = runCatching { reverseGeocode(lat, lon) }.getOrNull()
            if (ticket != generation.get()) {
                return@Thread
            }
            if (!name.isNullOrBlank() && userId.isNotBlank()) {
                persistPresentation(userId, name, lat, lon)
            }
            onResult(name)
        }.start()
    }

    private fun reverseGeocode(lat: Double, lon: Double): String? {
        if (!Geocoder.isPresent()) return null
        val geocoder = Geocoder(appContext, Locale.getDefault())
        if (Build.VERSION.SDK_INT >= 33) {
            var resolved: String? = null
            val latch = java.util.concurrent.CountDownLatch(1)
            geocoder.getFromLocation(lat, lon, 1) { addresses ->
                resolved = localityFrom(addresses.firstOrNull())
                latch.countDown()
            }
            try {
                latch.await(8, java.util.concurrent.TimeUnit.SECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            return resolved
        }
        @Suppress("DEPRECATION")
        val addresses = geocoder.getFromLocation(lat, lon, 1)
        return localityFrom(addresses?.firstOrNull())
    }

    private fun localityFrom(address: android.location.Address?): String? {
        if (address == null) return null
        return address.locality?.takeIf { it.isNotBlank() }
            ?: address.subAdminArea?.takeIf { it.isNotBlank() }
            ?: address.adminArea?.takeIf { it.isNotBlank() }
    }

    private fun persistPresentation(userId: String, name: String, lat: Double, lon: Double) {
        prefs.edit()
            .putString(KEY_OWNER, userId)
            .putString(KEY_NAME, name)
            .putLong(KEY_LAT, java.lang.Double.doubleToRawLongBits(lat))
            .putLong(KEY_LON, java.lang.Double.doubleToRawLongBits(lon))
            .apply()
    }

    private fun clearPresentation() {
        prefs.edit()
            .remove(KEY_OWNER)
            .remove(KEY_NAME)
            .remove(KEY_LAT)
            .remove(KEY_LON)
            .apply()
    }

    companion object {
        private const val PREFS_NAME = "hiair.place.geocoding"
        private const val KEY_OWNER = "presentation.owner"
        private const val KEY_NAME = "presentation.name"
        private const val KEY_LAT = "presentation.lat"
        private const val KEY_LON = "presentation.lon"
    }
}
