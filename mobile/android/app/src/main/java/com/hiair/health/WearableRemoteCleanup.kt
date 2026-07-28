package com.hiair.health

import com.hiair.network.ApiHttpException
import java.io.IOException

/**
 * Atomic, account-bound remote cleanup after local-first revoke.
 *
 * Tombstone fields survive logout/account switch. Retry is allowed only when the
 * authenticated [userId] matches [CleanupProgress.accountUserId]. Tokens are never stored.
 */
data class CleanupProgress(
    /** Account that owns this pending cleanup; empty when no tombstone. */
    val accountUserId: String = "",
    val pending: Boolean = false,
    val locallyRevoked: Boolean = false,
    val deleteDataRequested: Boolean = false,
    val healthDeleteDone: Boolean = false,
    val wearableDeleteDone: Boolean = false,
    val consentRevokeDone: Boolean = false,
    /** Safe error category only — never a health payload or token. */
    val lastErrorCategory: String? = null,
) {
    fun hasPendingTombstone(): Boolean = pending && accountUserId.isNotBlank()

    fun isRemoteFullyComplete(): Boolean {
        if (!consentRevokeDone) return false
        if (!deleteDataRequested) return true
        return healthDeleteDone && wearableDeleteDone
    }

    fun blocksConsentFor(userId: String): Boolean {
        return hasPendingTombstone() &&
            accountUserId == userId &&
            deleteDataRequested
    }

    fun blocksUploadsFor(userId: String): Boolean {
        if (userId.isBlank()) return false
        return hasPendingTombstone() && accountUserId == userId
    }
}

interface CleanupProgressStore {
    fun read(): CleanupProgress

    fun write(progress: CleanupProgress)

    /** Bumps sync generation so in-flight uploads are invalidated. */
    fun onLocalRevokeStarted()
}

data class CleanupRunResult(
    val remoteCleanupSucceeded: Boolean,
    val progress: CleanupProgress,
    val apiCalls: List<String>,
    val skippedForAccountMismatch: Boolean = false,
)

object CleanupErrorCategories {
    fun from(error: Throwable): String {
        return when (error) {
            is ApiHttpException -> "http_${error.statusCode}"
            is IOException -> {
                val msg = error.message.orEmpty().lowercase()
                if (msg.contains("timeout")) "timeout" else "network"
            }
            else -> "remote_cleanup_failed"
        }
    }
}

class WearableRemoteCleanup(
    private val api: WearableCleanupApi,
    private val store: CleanupProgressStore,
) {
    fun beginLocalRevoke(accountUserId: String, deleteData: Boolean): CleanupProgress {
        require(accountUserId.isNotBlank()) { "accountUserId required for cleanup tombstone" }
        store.onLocalRevokeStarted()
        val previous = store.read()
        val sameAccountPending =
            previous.hasPendingTombstone() && previous.accountUserId == accountUserId
        val continuingSameDelete =
            sameAccountPending && previous.deleteDataRequested && deleteData
        val deleteRequested =
            deleteData || (sameAccountPending && previous.deleteDataRequested)
        val next = CleanupProgress(
            accountUserId = accountUserId,
            pending = true,
            locallyRevoked = true,
            deleteDataRequested = deleteRequested,
            healthDeleteDone = if (continuingSameDelete) previous.healthDeleteDone else false,
            wearableDeleteDone = if (continuingSameDelete) previous.wearableDeleteDone else false,
            consentRevokeDone = continuingSameDelete && previous.consentRevokeDone,
            lastErrorCategory = null,
        )
        store.write(next)
        return next
    }

    /**
     * Runs remaining remote steps for [userId] only when it matches the tombstone account.
     * Never sends another account's token to APIs for a mismatched tombstone.
     */
    fun runRemoteCleanup(userId: String, accessToken: String?): CleanupRunResult {
        var progress = store.read()
        val calls = mutableListOf<String>()

        if (!progress.hasPendingTombstone() && !progress.locallyRevoked) {
            return CleanupRunResult(remoteCleanupSucceeded = true, progress = progress, apiCalls = emptyList())
        }

        if (progress.hasPendingTombstone() && progress.accountUserId != userId) {
            return CleanupRunResult(
                remoteCleanupSucceeded = false,
                progress = progress,
                apiCalls = emptyList(),
                skippedForAccountMismatch = true,
            )
        }

        if (progress.isRemoteFullyComplete()) {
            progress = emptyCompletedTombstone()
            store.write(progress)
            return CleanupRunResult(remoteCleanupSucceeded = true, progress = progress, apiCalls = emptyList())
        }

        if (!progress.pending) {
            return CleanupRunResult(remoteCleanupSucceeded = true, progress = progress, apiCalls = emptyList())
        }

        try {
            if (progress.deleteDataRequested) {
                if (!progress.healthDeleteDone) {
                    calls += "deleteHealthData"
                    api.deleteHealthData(userId, accessToken)
                    progress = progress.copy(healthDeleteDone = true, accountUserId = userId)
                    store.write(progress)
                }
                if (!progress.wearableDeleteDone) {
                    calls += "deleteWearableData"
                    api.deleteWearableData(userId, accessToken)
                    progress = progress.copy(wearableDeleteDone = true, accountUserId = userId)
                    store.write(progress)
                }
            }
            if (!progress.consentRevokeDone) {
                calls += "revokeWearableConsent"
                api.revokeWearableConsent(userId, accessToken)
                progress = progress.copy(consentRevokeDone = true, accountUserId = userId)
                store.write(progress)
            }
            progress = emptyCompletedTombstone()
            store.write(progress)
            return CleanupRunResult(remoteCleanupSucceeded = true, progress = progress, apiCalls = calls)
        } catch (error: Exception) {
            progress = progress.copy(
                pending = true,
                locallyRevoked = true,
                accountUserId = userId,
                lastErrorCategory = CleanupErrorCategories.from(error),
            )
            store.write(progress)
            return CleanupRunResult(remoteCleanupSucceeded = false, progress = progress, apiCalls = calls)
        }
    }

    fun canGrantConsent(userId: String): Boolean {
        if (userId.isBlank()) return false
        return !store.read().blocksConsentFor(userId)
    }

    private fun emptyCompletedTombstone(): CleanupProgress {
        return CleanupProgress(
            accountUserId = "",
            pending = false,
            locallyRevoked = true,
            deleteDataRequested = false,
            healthDeleteDone = false,
            wearableDeleteDone = false,
            consentRevokeDone = true,
            lastErrorCategory = null,
        )
    }
}

/**
 * Separates active consent session from the durable cleanup tombstone.
 * Production [HealthConnectService] and unit tests share this orchestration.
 */
class WearableConsentSessionCoordinator(
    private val cleanup: WearableRemoteCleanup,
    private val store: CleanupProgressStore,
    private val onActiveConsentCleared: () -> Unit,
    private val onConsentPersisted: (userId: String) -> Unit,
    private val readConsentUserId: () -> String,
    private val readHasDurableConsent: () -> Boolean,
) {
    /**
     * Logout / account switch: stop uploads + clear active consent, keep tombstone.
     */
    fun clearActiveConsentPreservingTombstone() {
        onActiveConsentCleared()
    }

    fun beginRevoke(accountUserId: String, deleteData: Boolean): CleanupProgress {
        return cleanup.beginLocalRevoke(accountUserId = accountUserId, deleteData = deleteData)
    }

    fun runCleanupForAuthenticatedUser(userId: String, accessToken: String?): CleanupRunResult {
        return cleanup.runRemoteCleanup(userId = userId, accessToken = accessToken)
    }

    /**
     * Persist consent only when it does not contradict a pending delete tombstone for this account.
     * Never clears another account's tombstone.
     */
    fun tryMarkConsentPersisted(userId: String): Boolean {
        if (userId.isBlank()) return false
        if (!cleanup.canGrantConsent(userId)) return false
        onConsentPersisted(userId)
        return true
    }

    fun tombstone(): CleanupProgress = store.read()

    fun pendingCleanupFor(userId: String): Boolean = store.read().blocksUploadsFor(userId)
}
