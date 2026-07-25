package com.hiair.health

/**
 * Pre-upload gate for health sync. All checks are re-evaluated immediately before each network write.
 */
object HealthUploadGate {
    data class Snapshot(
        val userId: String,
        val accountGeneration: Long,
        val syncGeneration: Long,
        val hasDurableConsent: Boolean,
        val consentUserId: String,
        val locallyRevoked: Boolean,
        val pendingRemoteCleanup: Boolean,
    )

    enum class BlockReason {
        LOCAL_REVOKE,
        CONSENT_MISSING,
        ACCOUNT_MISMATCH,
        STALE_ACCOUNT_GENERATION,
        STALE_SYNC_GENERATION,
        REMOTE_CLEANUP_PENDING,
    }

    fun assertAllowed(
        expectedUserId: String,
        expectedAccountGeneration: Long,
        expectedSyncGeneration: Long,
        snapshot: Snapshot,
    ): BlockReason? {
        if (snapshot.locallyRevoked || snapshot.pendingRemoteCleanup) {
            return if (snapshot.locallyRevoked) BlockReason.LOCAL_REVOKE else BlockReason.REMOTE_CLEANUP_PENDING
        }
        if (!snapshot.hasDurableConsent || snapshot.consentUserId.isBlank()) {
            return BlockReason.CONSENT_MISSING
        }
        if (expectedUserId.isBlank() || expectedUserId != snapshot.userId || expectedUserId != snapshot.consentUserId) {
            return BlockReason.ACCOUNT_MISMATCH
        }
        if (expectedAccountGeneration != snapshot.accountGeneration) {
            return BlockReason.STALE_ACCOUNT_GENERATION
        }
        if (expectedSyncGeneration != snapshot.syncGeneration) {
            return BlockReason.STALE_SYNC_GENERATION
        }
        return null
    }
}
