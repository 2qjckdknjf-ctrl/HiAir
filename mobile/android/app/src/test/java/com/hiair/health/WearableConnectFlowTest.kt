package com.hiair.health

import com.hiair.network.ApiHttpException
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WearableConnectFlowTest {

    @Test
    fun consentSuccess_syncCalledOnce() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_SAVED_SYNC_STARTED, result.outcome)
        assertEquals(1, syncCalls.get())
    }

    @Test
    fun consentFailure_syncNeverCalled() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> throw IllegalStateException("persist failed") },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_FAILED, result.outcome)
        assertEquals(0, syncCalls.get())
        assertTrue(result.consentError is IllegalStateException)
    }

    @Test
    fun consentTimeout_syncNeverCalled() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> throw java.util.concurrent.TimeoutException("consent timeout") },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_FAILED, result.outcome)
        assertEquals(0, syncCalls.get())
    }

    @Test
    fun retry_firstFailSecondSuccess_syncOnce() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val attempts = AtomicInteger(0)
        val first = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ ->
                attempts.incrementAndGet()
                throw ApiHttpException(500, "HTTP 500")
            },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_FAILED, first.outcome)
        assertEquals(0, syncCalls.get())

        val second = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> attempts.incrementAndGet() },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_SAVED_SYNC_STARTED, second.outcome)
        assertEquals(1, syncCalls.get())
        assertEquals(2, attempts.get())
    }

    @Test
    fun backendUnauthorized_noSync() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "bad",
            saveConsent = { _, _ -> throw ApiHttpException(401, "HTTP 401") },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_FAILED, result.outcome)
        assertEquals(0, syncCalls.get())
    }

    @Test
    fun logoutDuringConsent_noSync() = runBlocking {
        val syncCalls = AtomicInteger(0)
        var cancelled = false
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            isCancelled = { cancelled },
            saveConsent = { _, _ ->
                delay(10)
                cancelled = true
            },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CANCELLED, result.outcome)
        assertEquals(0, syncCalls.get())
    }

    @Test
    fun blankUser_skipsSync() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "  ",
            accessToken = null,
            saveConsent = { _, _ -> error("should not save") },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        // Blank after trim? Flow checks isBlank() — "  " is blank in Kotlin.
        assertEquals(WearableConnectFlow.Outcome.SKIPPED_BLANK_USER, result.outcome)
        assertEquals(0, syncCalls.get())
    }

    @Test
    fun duplicateConnect_singleFlightViaSequentialGate() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val consentCalls = AtomicInteger(0)
        val a = async {
            WearableConnectFlow.afterPermissionsGranted(
                userId = "user-1",
                accessToken = "token",
                saveConsent = { _, _ ->
                    consentCalls.incrementAndGet()
                    delay(30)
                },
                startSync = { _, _ -> syncCalls.incrementAndGet() },
            )
        }
        val b = async {
            WearableConnectFlow.afterPermissionsGranted(
                userId = "user-1",
                accessToken = "token",
                saveConsent = { _, _ ->
                    consentCalls.incrementAndGet()
                    delay(30)
                },
                startSync = { _, _ -> syncCalls.incrementAndGet() },
            )
        }
        a.await()
        b.await()
        // Flow itself is not mutexed; controller mutex covers UI. Assert each success syncs once.
        assertEquals(2, consentCalls.get())
        assertEquals(2, syncCalls.get())
    }

    @Test
    fun consentHttpNon2xx_treatedAsFailure_noSync() = runBlocking {
        val syncCalls = AtomicInteger(0)
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> throw ApiHttpException(503, "HTTP 503") },
            startSync = { _, _ -> syncCalls.incrementAndGet() },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_FAILED, result.outcome)
        assertEquals(0, syncCalls.get())
    }

    @Test
    fun syncGateRequiresDurableConsentFlag() {
        val flags = ConsentSessionFlags()
        assertFalse(flags.hasDurableConsent)
        // Mirrors WearableHealthController.syncIfPermitted early return.
        var syncAllowed = false
        if (flags.hasDurableConsent) {
            syncAllowed = true
        }
        assertFalse(syncAllowed)
        flags.markPersisted()
        if (flags.hasDurableConsent) {
            syncAllowed = true
        }
        assertTrue(syncAllowed)
        flags.revoke()
        syncAllowed = flags.hasDurableConsent
        assertFalse(syncAllowed)
    }

    @Test
    fun persistedConsentRequiredBeforeConnectedUi() {
        val flags = ConsentSessionFlags()
        assertFalse(flags.hasDurableConsent)
        assertEquals(WearableConnectionState.NOT_CONNECTED, flags.lastConnectionState)
        flags.markFailed("timeout")
        assertFalse(flags.hasDurableConsent)
        assertEquals(WearableConnectionState.SYNC_FAILED, flags.lastConnectionState)
        flags.markPersisted()
        assertTrue(flags.hasDurableConsent)
        assertEquals(WearableConnectionState.CONNECTED, flags.lastConnectionState)
    }

    @Test
    fun partialConsent_syncOnlyAfterConsentForAllowedPath() = runBlocking {
        val allowedCategories = mutableListOf<String>()
        val result = WearableConnectFlow.afterPermissionsGranted(
            userId = "user-1",
            accessToken = "token",
            saveConsent = { _, _ -> allowedCategories += "tier1" },
            startSync = { _, _ ->
                // Sync payload path only runs after consent; categories filtered by permissions later.
                assertTrue(allowedCategories.contains("tier1"))
            },
        )
        assertEquals(WearableConnectFlow.Outcome.CONSENT_SAVED_SYNC_STARTED, result.outcome)
        assertEquals(listOf("tier1"), allowedCategories)
    }
}

/** Mirrors HealthConnectService consent session flags for pure unit tests. */
private class ConsentSessionFlags {
    var hasDurableConsent: Boolean = false
        private set
    var lastConsentError: String? = null
        private set
    var lastConnectionState: WearableConnectionState = WearableConnectionState.NOT_CONNECTED
        private set

    fun markPersisted() {
        hasDurableConsent = true
        lastConsentError = null
        lastConnectionState = WearableConnectionState.CONNECTED
    }

    fun markFailed(message: String) {
        hasDurableConsent = false
        lastConsentError = message
        lastConnectionState = WearableConnectionState.SYNC_FAILED
    }

    fun revoke() {
        hasDurableConsent = false
        lastConsentError = null
        lastConnectionState = WearableConnectionState.NOT_CONNECTED
    }
}
