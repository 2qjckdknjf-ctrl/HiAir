package com.hiair.health

import android.content.Context
import com.hiair.ui.i18n.AndroidL10n

data class HealthSnapshot(
    val available: Boolean,
    val steps: Int? = null,
    val restingHeartRate: Int? = null,
    val sleepHours: Double? = null,
    val sleepQuality: Int? = null,
    val statusMessage: String = ""
)

/**
 * Health Connect foundation. Reads are optional and never required for core app flows.
 */
class HealthConnectService(private val context: Context) {
    fun isAvailable(): Boolean {
        return try {
            Class.forName("androidx.health.connect.client.HealthConnectClient")
            false
        } catch (_: ClassNotFoundException) {
            false
        }
    }

    fun readOptionalSnapshot(language: String, optedIn: Boolean): HealthSnapshot {
        if (!optedIn) {
            return HealthSnapshot(
                available = false,
                statusMessage = AndroidL10n.t("health.skipped", language)
            )
        }
        if (!isAvailable()) {
            return HealthSnapshot(
                available = false,
                statusMessage = AndroidL10n.t("health.not_installed", language)
            )
        }
        return HealthSnapshot(
            available = false,
            statusMessage = AndroidL10n.t("health.permission_needed", language)
        )
    }
}
