package com.hiair.health

import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Wires Health Connect permission requests and backend consent/sync from the main activity.
 * Sync is never started unless consent persistence succeeds (HTTP 2xx).
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
    private var syncJob: Job? = null
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
     * Account-bound cleanup tombstone is preserved for later same-account retry.
     */
    fun cancelPendingOperations() {
        connectGeneration += 1
        healthService.bumpSyncGeneration()
        connectJob?.cancel()
        connectJob = null
        syncJob?.cancel()
        syncJob = null
        pendingUserId = ""
        pendingAccessToken = null
        pendingCallback = null
        healthService.clearConsentSession()
    }

    /**
     * Local-first revoke: stop uploads immediately, cancel in-flight sync, then attempt remote cleanup.
     * @return true when remote cleanup also succeeded; false when local stop succeeded but server needs retry.
     */
    suspend fun revokeLocalFirst(
        userId: String,
        accessToken: String?,
        deleteData: Boolean = false,
    ): Boolean {
        connectGeneration += 1
        healthService.markConsentRevokedLocally(userId = userId, deleteData = deleteData)
        syncJob?.cancel()
        syncJob = null
        connectJob?.cancel()
        connectJob = null
        pendingCallback = null
        return withContext(Dispatchers.IO) {
            healthService.performRemoteCleanup(userId, accessToken)
        }
    }

    fun retryPendingRemoteCleanup(userId: String, accessToken: String?, deleteData: Boolean = false) {
        val tombstone = healthService.cleanupProgressSnapshot()
        if (!tombstone.hasPendingTombstone()) return
        if (tombstone.accountUserId != userId) return
        activity.lifecycleScope.launch {
            healthService.retryRemoteCleanup(userId, accessToken, deleteData = deleteData)
        }
    }

    fun syncIfPermitted(userId: String, accessToken: String?, profileId: String? = null) {
        if (userId.isBlank() || !healthService.isHealthConnectAvailable()) return
        // Fail closed: OS permissions alone are not enough; consent must match this account.
        if (!healthService.hasDurableConsentFor(userId)) return
        val generation = connectGeneration
        val accountGeneration = healthService.accountGeneration
        val syncGeneration = healthService.syncGeneration
        syncJob?.cancel()
        syncJob = activity.lifecycleScope.launch {
            if (generation != connectGeneration) return@launch
            val granted = withContext(Dispatchers.IO) {
                // Permission probe is local IPC; keep off main when possible.
                healthService.grantedPermissions()
            }
            if (generation != connectGeneration) return@launch
            if (granted.any { it in healthService.tier1Permissions }) {
                healthService.syncHealthIntelligence(
                    userId = userId,
                    accessToken = accessToken,
                    profileId = profileId,
                    expectedAccountGeneration = accountGeneration,
                    expectedSyncGeneration = syncGeneration,
                )
            }
        }
    }

    /**
     * Call when auth identity changes (login / OAuth / expiry) so another account
     * cannot inherit durable consent or in-flight sync from the previous user.
     * Matching tombstone owner may retry cleanup with the new token; mismatched accounts never do.
     */
    fun onAuthenticatedUserChanged(userId: String, accountGeneration: Long, accessToken: String? = null) {
        healthService.bindAccountGeneration(accountGeneration)
        if (userId.isBlank()) {
            cancelPendingOperations()
            return
        }
        val previousConsentUser = healthService.consentUserId
        if (previousConsentUser.isNotBlank() && previousConsentUser != userId) {
            // Switch away from previous account's active consent; keep tombstone.
            cancelPendingOperations()
        }
        val tombstone = healthService.cleanupProgressSnapshot()
        if (tombstone.hasPendingTombstone() && tombstone.accountUserId == userId && !accessToken.isNullOrBlank()) {
            activity.lifecycleScope.launch {
                healthService.retryRemoteCleanup(userId, accessToken)
            }
        }
    }

    private suspend fun completeConnect(onComplete: (() -> Unit)?) {
        connectMutex.withLock {
            val generation = connectGeneration
            val userId = pendingUserId
            val token = pendingAccessToken
            val accountGeneration = healthService.accountGeneration
            val job = activity.lifecycleScope.launch {
                val result = WearableConnectFlow.afterPermissionsGranted(
                    userId = userId,
                    accessToken = token,
                    isCancelled = { generation != connectGeneration },
                    saveConsent = { uid, access ->
                        withContext(Dispatchers.IO) {
                            healthService.saveConsent(uid, access)
                        }
                    },
                    startSync = { uid, access ->
                        if (generation == connectGeneration) {
                            val syncGeneration = healthService.syncGeneration
                            syncJob?.cancel()
                            syncJob = activity.lifecycleScope.launch syncLaunch@{
                                if (generation != connectGeneration) return@syncLaunch
                                try {
                                    healthService.syncHealthIntelligence(
                                        userId = uid,
                                        accessToken = access,
                                        profileId = null,
                                        expectedAccountGeneration = accountGeneration,
                                        expectedSyncGeneration = syncGeneration,
                                    )
                                } catch (_: Exception) {
                                    // Non-blocking — dashboard still works without wearable sync.
                                }
                            }
                        }
                    },
                )
                when (result.outcome) {
                    WearableConnectFlow.Outcome.CONSENT_SAVED_SYNC_STARTED -> {
                        healthService.markConsentPersisted(userId)
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
