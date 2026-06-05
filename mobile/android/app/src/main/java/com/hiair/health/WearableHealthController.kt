package com.hiair.health

import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/**
 * Wires Health Connect permission requests and backend consent/sync from the main activity.
 */
class WearableHealthController(
    private val activity: ComponentActivity,
    private val healthService: HealthConnectService,
) {
    private val permissionLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            val callback = pendingCallback
            pendingCallback = null
            if (granted.containsAll(healthService.readPermissions)) {
                activity.lifecycleScope.launch {
                    completeConnect(callback)
                }
            } else {
                callback?.invoke()
            }
        }

    private var pendingCallback: (() -> Unit)? = null

    fun requestConnect(userId: String, accessToken: String?, onComplete: () -> Unit) {
        if (userId.isBlank()) {
            onComplete()
            return
        }
        if (!healthService.isHealthConnectAvailable()) {
            healthService.healthConnectInstallIntent()?.let { activity.startActivity(it) }
            onComplete()
            return
        }
        pendingUserId = userId
        pendingAccessToken = accessToken
        pendingCallback = onComplete
        activity.lifecycleScope.launch {
            if (healthService.hasAllPermissions()) {
                completeConnect(onComplete)
            } else {
                permissionLauncher.launch(healthService.readPermissions)
            }
        }
    }

    fun syncIfPermitted(userId: String, accessToken: String?) {
        if (userId.isBlank() || !healthService.isHealthConnectAvailable()) return
        activity.lifecycleScope.launch {
            if (healthService.hasAllPermissions()) {
                healthService.syncWearableDailySummary(userId, accessToken)
            }
        }
    }

    private var pendingUserId: String = ""
    private var pendingAccessToken: String? = null

    private suspend fun completeConnect(onComplete: (() -> Unit)?) {
        val userId = pendingUserId
        val token = pendingAccessToken
        if (userId.isNotBlank()) {
            try {
                healthService.saveConsent(userId, token)
                healthService.syncWearableDailySummary(userId, token)
            } catch (_: Exception) {
                // Non-blocking — dashboard still works without wearable sync.
            }
        }
        onComplete?.invoke()
    }
}
