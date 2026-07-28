package com.hiair.health

import com.hiair.network.ApiHttpException
import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Production-path tests for account-bound [WearableRemoteCleanup] +
 * [WearableConsentSessionCoordinator] (same orchestration HealthConnectService uses).
 * No real network.
 */
class HealthConsentRaceTest {

    @Test
    fun firstDeleteEndpoint500_keepsPendingAndBlocksUploads() {
        val api = FakeCleanupApi(failOn = setOf("deleteHealthData"), status = 500)
        val (cleanup, store, _) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        val result = cleanup.runRemoteCleanup("user-a", "token-a")
        assertFalse(result.remoteCleanupSucceeded)
        assertTrue(store.read().pending)
        assertEquals("user-a", store.read().accountUserId)
        assertEquals(listOf("deleteHealthData"), result.apiCalls)
        assertUploadBlocked(store, "user-a")
    }

    @Test
    fun secondDeleteEndpoint500_keepsPendingAfterHealthDeleted() {
        val api = FakeCleanupApi(failOn = setOf("deleteWearableData"), status = 500)
        val (cleanup, store, _) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        val result = cleanup.runRemoteCleanup("user-a", "token-a")
        assertFalse(result.remoteCleanupSucceeded)
        assertTrue(store.read().healthDeleteDone)
        assertFalse(store.read().wearableDeleteDone)
        assertEquals(listOf("deleteHealthData", "deleteWearableData"), result.apiCalls)
        assertUploadBlocked(store, "user-a")
    }

    @Test
    fun revoke500AfterSuccessfulDeletes_keepsPending() {
        val api = FakeCleanupApi(failOn = setOf("revokeWearableConsent"), status = 500)
        val (cleanup, store, _) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        assertFalse(cleanup.runRemoteCleanup("user-a", "token-a").remoteCleanupSucceeded)
        assertTrue(store.read().healthDeleteDone)
        assertTrue(store.read().wearableDeleteDone)
        assertFalse(store.read().consentRevokeDone)
        assertTrue(store.read().deleteDataRequested)
        assertUploadBlocked(store, "user-a")
    }

    @Test
    fun timeoutOnEachStep_keepsPending() {
        listOf("deleteHealthData", "deleteWearableData", "revokeWearableConsent").forEach { step ->
            val api = FakeCleanupApi(timeoutOn = setOf(step))
            val (cleanup, store, _) = harness(api)
            cleanup.beginLocalRevoke("user-a", deleteData = true)
            assertFalse(cleanup.runRemoteCleanup("user-a", "token-a").remoteCleanupSucceeded)
            assertTrue(store.read().pending)
            assertEquals("timeout", store.read().lastErrorCategory)
            assertUploadBlocked(store, "user-a")
        }
    }

    @Test
    fun partialDeleteFailure_logout_preservesTombstone() {
        val api = FakeCleanupApi(failOn = setOf("deleteWearableData"), status = 500)
        val (cleanup, store, session) = harness(api)
        session.simulateConsentPersisted("user-a")
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        assertTrue(store.read().hasPendingTombstone())

        session.clearActiveConsentPreservingTombstone()
        assertEquals("", session.activeConsentUserId)
        assertFalse(session.hasDurableConsent)
        assertTrue(store.read().hasPendingTombstone())
        assertEquals("user-a", store.read().accountUserId)
        assertTrue(store.read().deleteDataRequested)
        assertTrue(store.read().healthDeleteDone)
    }

    @Test
    fun coldStart_restoreSessionBinding_retriesPendingWithRestoredTokenNotOtherAccount() {
        // Production path: AppMainActivity.restoreSession() must immediately call
        // onAuthenticatedUserChanged(restoredUser, generation, restoredToken).
        val api = FakeCleanupApi(failOn = setOf("revokeWearableConsent"), status = 500)
        val memory = InMemoryCleanupStore()
        val cleanup = WearableRemoteCleanup(api, memory)
        val session = SessionHarness(cleanup, memory)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-old")
        session.clearActiveConsentPreservingTombstone()

        // Cold start: durable tombstone survives process death; no active consent.
        val restoredStore = InMemoryCleanupStore(initial = memory.read())
        val retryApi = FakeCleanupApi()
        val retryCleanup = WearableRemoteCleanup(retryApi, restoredStore)
        val coldStart = SessionHarness(retryCleanup, restoredStore)

        assertTrue(restoredStore.read().hasPendingTombstone())
        assertEquals("user-a", restoredStore.read().accountUserId)

        // Other account's restored session must never use its token for A's tombstone.
        val other = coldStart.runCleanupForAuthenticatedUser("user-b", "token-b")
        assertTrue(other.skippedForAccountMismatch)
        assertTrue(other.apiCalls.isEmpty())
        assertTrue(retryApi.tokenCalls.none { it.second == "token-b" })
        assertTrue(restoredStore.read().hasPendingTombstone())

        // Matching restored session retries remaining steps with restored token only.
        val result = coldStart.runCleanupForAuthenticatedUser("user-a", "token-restored")
        assertTrue(result.remoteCleanupSucceeded)
        assertEquals(listOf("revokeWearableConsent"), result.apiCalls)
        assertEquals(0, retryApi.tokenCalls.count { it.second != "token-restored" })
        assertFalse(restoredStore.read().hasPendingTombstone())
    }

    @Test
    fun logoutRestart_loginSameUser_runsOnlyRemainingSteps() {
        val api = FakeCleanupApi(failOn = setOf("revokeWearableConsent"), status = 500)
        val memory = InMemoryCleanupStore()
        val cleanup = WearableRemoteCleanup(api, memory)
        val session = SessionHarness(cleanup, memory)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-old")
        session.clearActiveConsentPreservingTombstone()

        // Process restart: rehydrate tombstone only.
        val restored = InMemoryCleanupStore(initial = memory.read())
        val retryApi = FakeCleanupApi()
        val retryCleanup = WearableRemoteCleanup(retryApi, restored)
        val restoredSession = SessionHarness(retryCleanup, restored)
        restoredSession.clearActiveConsentPreservingTombstone()

        assertTrue(restored.read().hasPendingTombstone())
        assertEquals("user-a", restored.read().accountUserId)

        val result = restoredSession.runCleanupForAuthenticatedUser("user-a", "token-new")
        assertTrue(result.remoteCleanupSucceeded)
        assertEquals(listOf("revokeWearableConsent"), result.apiCalls)
        assertFalse(restored.read().hasPendingTombstone())
        assertEquals(0, retryApi.tokenCalls.count { it.second != "token-new" })
    }

    @Test
    fun loginOtherUser_doesNotRunCleanupOrPassWrongToken() {
        val api = FakeCleanupApi(failOn = setOf("deleteHealthData"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()

        api.failOn = emptySet()
        val result = session.runCleanupForAuthenticatedUser("user-b", "token-b")
        assertTrue(result.skippedForAccountMismatch)
        assertFalse(result.remoteCleanupSucceeded)
        assertTrue(result.apiCalls.isEmpty())
        assertTrue(store.read().hasPendingTombstone())
        assertEquals("user-a", store.read().accountUserId)
        assertTrue(api.tokenCalls.none { it.second == "token-b" })
        assertTrue(session.tryMarkConsentPersisted("user-b"))
        assertEquals("user-b", session.activeConsentUserId)
        assertTrue(store.read().hasPendingTombstone())
    }

    @Test
    fun accountSwitch_doesNotClearPendingDeleteForA() {
        val api = FakeCleanupApi(failOn = setOf("deleteWearableData"), status = 500)
        val (cleanup, store, session) = harness(api)
        session.simulateConsentPersisted("user-a")
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()
        assertTrue(session.tryMarkConsentPersisted("user-b"))
        assertTrue(store.read().hasPendingTombstone())
        assertEquals("user-a", store.read().accountUserId)
        assertTrue(store.read().deleteDataRequested)
    }

    @Test
    fun successfulRetryA_removesTombstone() {
        val api = FakeCleanupApi(failOn = setOf("revokeWearableConsent"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()
        api.failOn = emptySet()
        assertTrue(session.runCleanupForAuthenticatedUser("user-a", "token-a2").remoteCleanupSucceeded)
        assertFalse(store.read().hasPendingTombstone())
        assertEquals("", store.read().accountUserId)
    }

    @Test
    fun pendingCleanupContinuesBlockingUploadsForA() {
        val api = FakeCleanupApi(failOn = setOf("deleteHealthData"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()
        assertUploadBlocked(store, "user-a")
        assertFalse(store.read().blocksUploadsFor("user-b"))
    }

    @Test
    fun consentOfOtherUserIsIsolated_andSameAccountDeleteBlocksNewConsent() {
        val api = FakeCleanupApi(failOn = setOf("deleteHealthData"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()
        assertFalse(session.tryMarkConsentPersisted("user-a"))
        assertTrue(session.tryMarkConsentPersisted("user-b"))
        assertEquals("user-b", session.activeConsentUserId)
        assertTrue(store.read().hasPendingTombstone())
    }

    @Test
    fun repeatedLogoutDoesNotDamageProgress() {
        val api = FakeCleanupApi(failOn = setOf("deleteWearableData"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        val mid = store.read()
        repeat(3) { session.clearActiveConsentPreservingTombstone() }
        assertEquals(mid.accountUserId, store.read().accountUserId)
        assertEquals(mid.healthDeleteDone, store.read().healthDeleteDone)
        assertEquals(mid.wearableDeleteDone, store.read().wearableDeleteDone)
        assertTrue(store.read().hasPendingTombstone())
    }

    @Test
    fun http401OrTimeoutAfterReLogin_keepsTombstonePending() {
        val api = FakeCleanupApi(failOn = setOf("revokeWearableConsent"), status = 500)
        val (cleanup, store, session) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        cleanup.runRemoteCleanup("user-a", "token-a")
        session.clearActiveConsentPreservingTombstone()

        api.failOn = setOf("revokeWearableConsent")
        api.status = 401
        assertFalse(session.runCleanupForAuthenticatedUser("user-a", "token-new").remoteCleanupSucceeded)
        assertTrue(store.read().hasPendingTombstone())
        assertEquals("http_401", store.read().lastErrorCategory)

        api.failOn = emptySet()
        api.timeoutOn = setOf("revokeWearableConsent")
        assertFalse(session.runCleanupForAuthenticatedUser("user-a", "token-new2").remoteCleanupSucceeded)
        assertTrue(store.read().hasPendingTombstone())
        assertEquals("timeout", store.read().lastErrorCategory)
    }

    @Test
    fun alreadyCompleteCleanup_doesNotCallServerAgain() {
        val api = FakeCleanupApi()
        val (cleanup, _, _) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        assertTrue(cleanup.runRemoteCleanup("user-a", "token-a").remoteCleanupSucceeded)
        val second = cleanup.runRemoteCleanup("user-a", "token-a")
        assertTrue(second.remoteCleanupSucceeded)
        assertTrue(second.apiCalls.isEmpty())
        assertEquals(1, api.counts["deleteHealthData"]?.get())
    }

    @Test
    fun full2xxCleanup_clearsPending_stillBlocksUntilNewConsent() {
        val api = FakeCleanupApi()
        val (cleanup, store, _) = harness(api)
        cleanup.beginLocalRevoke("user-a", deleteData = true)
        assertTrue(cleanup.runRemoteCleanup("user-a", "token-a").remoteCleanupSucceeded)
        assertFalse(store.read().hasPendingTombstone())
        assertTrue(store.read().locallyRevoked)
    }

    private fun harness(
        api: FakeCleanupApi,
    ): Triple<WearableRemoteCleanup, InMemoryCleanupStore, SessionHarness> {
        val store = InMemoryCleanupStore()
        val cleanup = WearableRemoteCleanup(api, store)
        return Triple(cleanup, store, SessionHarness(cleanup, store))
    }

    private fun assertUploadBlocked(store: InMemoryCleanupStore, userId: String) {
        val progress = store.read()
        val snapshot = HealthUploadGate.Snapshot(
            userId = userId,
            accountGeneration = store.accountGeneration,
            syncGeneration = store.syncGeneration,
            hasDurableConsent = false,
            consentUserId = "",
            locallyRevoked = progress.blocksUploadsFor(userId),
            pendingRemoteCleanup = progress.blocksUploadsFor(userId),
        )
        assertNotNull(
            HealthUploadGate.assertAllowed(
                expectedUserId = userId,
                expectedAccountGeneration = store.accountGeneration,
                expectedSyncGeneration = store.syncGeneration,
                snapshot = snapshot,
            ),
        )
    }
}

private class SessionHarness(
    cleanup: WearableRemoteCleanup,
    private val store: InMemoryCleanupStore,
) {
    var activeConsentUserId: String = ""
        private set
    var hasDurableConsent: Boolean = false
        private set

    private val coordinator = WearableConsentSessionCoordinator(
        cleanup = cleanup,
        store = store,
        onActiveConsentCleared = {
            activeConsentUserId = ""
            hasDurableConsent = false
            store.onLocalRevokeStarted()
        },
        onConsentPersisted = { userId ->
            activeConsentUserId = userId
            hasDurableConsent = true
        },
        readConsentUserId = { activeConsentUserId },
        readHasDurableConsent = { hasDurableConsent },
    )

    fun clearActiveConsentPreservingTombstone() = coordinator.clearActiveConsentPreservingTombstone()

    fun runCleanupForAuthenticatedUser(userId: String, accessToken: String?) =
        coordinator.runCleanupForAuthenticatedUser(userId, accessToken)

    fun tryMarkConsentPersisted(userId: String): Boolean = coordinator.tryMarkConsentPersisted(userId)

    fun simulateConsentPersisted(userId: String) {
        activeConsentUserId = userId
        hasDurableConsent = true
    }
}

private class FakeCleanupApi(
    var failOn: Set<String> = emptySet(),
    var timeoutOn: Set<String> = emptySet(),
    var status: Int = 500,
) : WearableCleanupApi {
    val counts = mutableMapOf<String, AtomicInteger>()
    val tokenCalls = mutableListOf<Pair<String, String?>>()

    private fun hit(name: String, userId: String, accessToken: String?) {
        counts.getOrPut(name) { AtomicInteger(0) }.incrementAndGet()
        tokenCalls += userId to accessToken
        if (name in timeoutOn) {
            throw IOException("timeout:$name")
        }
        if (name in failOn) {
            throw ApiHttpException(status, "HTTP $status on $name")
        }
    }

    override fun deleteHealthData(userId: String, accessToken: String?): String {
        hit("deleteHealthData", userId, accessToken)
        return "{}"
    }

    override fun deleteWearableData(userId: String, accessToken: String?): String {
        hit("deleteWearableData", userId, accessToken)
        return "{}"
    }

    override fun revokeWearableConsent(userId: String, accessToken: String?): String {
        hit("revokeWearableConsent", userId, accessToken)
        return "{}"
    }
}

private class InMemoryCleanupStore(
    initial: CleanupProgress = CleanupProgress(),
) : CleanupProgressStore {
    private var progress = initial
    var accountGeneration: Long = 1
    var syncGeneration: Long = 1

    override fun read(): CleanupProgress = progress

    override fun write(progress: CleanupProgress) {
        this.progress = progress
    }

    override fun onLocalRevokeStarted() {
        syncGeneration += 1
    }
}
