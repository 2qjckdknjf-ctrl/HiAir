package com.hiair.health

/**
 * Consent-before-sync gate for Health Connect connect completion.
 * Health sync runs only after durable consent persistence succeeds.
 */
object WearableConnectFlow {
    enum class Outcome {
        CONSENT_SAVED_SYNC_STARTED,
        CONSENT_FAILED,
        CANCELLED,
        SKIPPED_BLANK_USER,
    }

    data class Result(
        val outcome: Outcome,
        val consentError: Throwable? = null,
    )

    /**
     * Canonical post-permission path:
     * saveConsent → verify success → only then startSync.
     */
    suspend fun afterPermissionsGranted(
        userId: String,
        accessToken: String?,
        isCancelled: () -> Boolean = { false },
        saveConsent: suspend (userId: String, accessToken: String?) -> Unit,
        startSync: suspend (userId: String, accessToken: String?) -> Unit,
    ): Result {
        if (userId.isBlank()) {
            return Result(Outcome.SKIPPED_BLANK_USER)
        }
        if (isCancelled()) {
            return Result(Outcome.CANCELLED)
        }
        try {
            saveConsent(userId, accessToken)
        } catch (error: Exception) {
            return Result(Outcome.CONSENT_FAILED, error)
        }
        if (isCancelled()) {
            return Result(Outcome.CANCELLED)
        }
        startSync(userId, accessToken)
        return Result(Outcome.CONSENT_SAVED_SYNC_STARTED)
    }
}
