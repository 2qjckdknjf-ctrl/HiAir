package com.hiair.health

import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Wires Health Connect permission requests and backend consent/sync from the main activity.
 * Sync is never started unless consent persistence succeeds.
 */
class WearableHealthController(
    private val activity: ComponentActivity,
    private val healthService: HealthConnectService,
) {
    private val permissionLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(PermissionController.createRequestPermissionResultContract()) { granted ->
            val callback = pendingCallback
            pendingCallback = null
            // Progressive consent: continue if at least activity/sleep tier is granted.
            if (granted.any { it in healthService.tier1Permissions }) {
                activity.lifecycleScope.launch {
                    completeConnect(callback)
                }
            } else {
                healthService.markConsentFailed("permission_denied")
                callback?.invoke()
            }
        }

    private var pendingCallback: (() -> Unit)? = null
    private var pendingUserId: String = ""
    private var pendingAccessToken: String? = null
    private var connectGeneration: Long = 0L
    private var connectJob: Job? = null
    private val connectMutex = Mutex()

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
            val granted = healthService.grantedPermissions()
            if (granted.containsAll(healthService.tier1Permissions)) {
                completeConnect(onComplete)
            } else {
                // Request full set; user may grant partially.
                permissionLauncher.launch(healthService.readPermissions)
            }
        }
    }

    /**
     * Call on logout / account switch so pending consent/sync cannot leak across users.
     */
    fun cancelPendingOperations() {
        connectGeneration += 1
        connectJob?.cancel()
        connectJob = null
        pendingUserId = ""
        pendingAccessToken = null
        pendingCallback = null
        healthService.clearConsentSession()
    }

    fun syncIfPermitted(userId: String, accessToken: String?, profileId: String? = null) {
        if (userId.isBlank() || !healthService.isHealthConnectAvailable()) return
        activity.lifecycleScope.launch {
            val granted = healthService.grantedPermissions()
            if (granted.any { it in healthService.tier1Permissions }) {
                healthService.syncHealthIntelligence(userId, accessToken, profileId)
            }
        }
    }

    private suspend fun completeConnect(onComplete: (() -> Unit)?) {
        connectMutex.withLock {
            val generation = connectGeneration
            val userId = pendingUserId
            val token = pendingAccessToken
            val job = activity.lifecycleScope.launch {
                val result = WearableConnectFlow.afterPermissionsGranted(
                    userId = userId,
                    accessToken = token,
                    isCancelled = { generation != connectGeneration },
                    saveConsent = { uid, access ->
                        healthService.saveConsent(uid, access)
                    },
                    startSync = { uid, access ->
                        activity.lifecycleScope.launch {
                            try {
                                healthService.syncHealthIntelligence(uid, access, profileId = null)
                            } catch (_: Exception) {
                                // Non-blocking — dashboard still works without wearable sync.
                            }
                        }
                    },
                )
                when (result.outcome) {
                    WearableConnectFlow.Outcome.CONSENT_SAVED_SYNC_STARTED -> {
                        healthService.markConsentPersisted()
                    }
                    WearableConnectFlow.Outcome.CONSENT_FAILED -> {
                        healthService.markConsentFailed(result.consentError?.message ?: "consent_failed")
                    }
                    WearableConnectFlow.Outcome.CANCELLED,
                    WearableConnectFlow.Outcome.SKIPPED_BLANK_USER -> {
                        // No sync; leave UI recoverable.
                    }
                }
                if (generation == connectGeneration) {
                    onComplete?.invoke()
                }
            }
            connectJob = job
            job.join()
        }
    }
}
