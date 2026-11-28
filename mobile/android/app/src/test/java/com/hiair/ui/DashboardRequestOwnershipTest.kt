package com.hiair.ui

import com.hiair.network.ApiClient
import java.io.IOException
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentMatchers.*
import org.mockito.Mockito.*

class DashboardRequestOwnershipTest {
    // Java Mockito eq returns null; Kotlin String parameters need a non-null placeholder.
    private fun eqString(value: String): String = eq(value) ?: value

    private val owner = AtomicReference<String?>("user-a")
    private lateinit var api: ApiClient
    private lateinit var model: DashboardViewModel

    @Before
    fun setUp() {
        api = mock(ApiClient::class.java)
        model = DashboardViewModel(api)
        ApiClient.configureAuth(provider = {
            owner.get()?.let { ApiClient.AuthState(it, "token", "refresh") }
        }, updater = null)
    }

    @After
    fun tearDown() {
        ApiClient.configureAuth(provider = null, updater = null)
    }

    private fun risk(headline: String) = """{"risk":{"overallRisk":"low"},"recommendation":{"headline":"$headline","actions":[]}}"""

    private fun load(userId: String, profile: String = "profile", ready: (() -> Unit)? = null) {
        model.load(userId, "token", profile, "en", onRiskReady = ready)
    }

    @Test
    fun missingIdentityReleasesThePendingSpinnerToEmptyWithoutNetwork() {
        val generation = model.markLoading()
        // Explicit absence from the identity snapshot must not fall back to an
        // older refresh-eligible snapshot for account A.
        ApiClient.configureAuth(
            provider = { ApiClient.AuthState("user-a", "token", "refresh") },
            updater = null,
            identityProvider = { null },
        )
        model.load("user-a", "token", "profile", "en", pendingGeneration = generation)
        assertEquals(DashboardStatus.EMPTY, model.state.status)
        assertTrue(model.ownsLoadGeneration(generation))
        verifyNoInteractions(api)
    }

    @Test
    fun usableIdentityWithoutRefreshTokenCanCompleteThePendingLoad() {
        ApiClient.configureAuth(
            provider = { null }, // Existing refresh policy still rejects this session.
            updater = null,
            identityProvider = { ApiClient.AuthState("user-a", "token", "") },
        )
        val generation = model.markLoading()
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenReturn(risk("account A"))
        model.load("user-a", "token", "profile", "en", pendingGeneration = generation)
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account A", model.state.headline)
        verify(api).fetchCurrentRisk(eqString("user-a"), anyString(), anyString())
    }

    @Test
    fun queuedOwnerRejectionReleasesItsSpinnerForTheCurrentAccount() {
        val generation = model.markLoading()
        owner.set("user-b")
        model.load("user-a", "token", "profile", "en", pendingGeneration = generation)
        assertEquals(DashboardStatus.INITIAL, model.state.status)
        assertTrue(model.ownsLoadGeneration(generation))
        verifyNoInteractions(api)
    }

    @Test
    fun cancelledProfileLookupCanRestartForTheCurrentAccount() {
        val generation = model.markLoading()
        owner.set("user-b")
        assertTrue(model.cancelLoad(generation))
        assertEquals(DashboardStatus.INITIAL, model.state.status)
        val replacement = model.markLoading()
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenReturn(risk("account B"))
        model.load("user-b", "token", "profile", "en", pendingGeneration = replacement)
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account B", model.state.headline)
        assertFalse(model.ownsLoadGeneration(generation))
    }

    @Test
    fun supersededPendingTicketCannotCancelOrReplaceTheNewAccountsLoad() {
        val oldGeneration = model.markLoading()
        owner.set("user-b")
        val newGeneration = model.markLoading()
        `when`(api.fetchCurrentRisk(eqString("user-b"), anyString(), anyString())).thenAnswer {
            assertFalse(model.cancelLoad(oldGeneration))
            model.load("user-a", "token", "profile", "en", pendingGeneration = oldGeneration)
            assertEquals(DashboardStatus.LOADING, model.state.status)
            risk("account B")
        }
        model.load("user-b", "token", "profile", "en", pendingGeneration = newGeneration)
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account B", model.state.headline)
        verify(api, never()).fetchCurrentRisk(eqString("user-a"), anyString(), anyString())
    }

    @Test
    fun lostIdentityBeforePrimaryApplyEndsLoadingWithoutAnExplicitReset() {
        var ready = 0
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer {
            owner.set(null)
            risk("account A")
        }
        load("user-a", ready = { ready++ })
        assertEquals(DashboardStatus.EMPTY, model.state.status)
        assertNull(model.state.headline)
        assertEquals(0, ready)
    }

    @Test
    fun accountSwitchBeforeQueuedFinalRenderClearsTheCompletedOldPayload() {
        val generation = model.markLoading()
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenReturn(risk("account A"))
        model.load("user-a", "token", "profile", "en", pendingGeneration = generation)
        assertEquals("account A", model.state.headline)
        owner.set("user-b")
        // This is the same helper called by the queued final UI callback.
        assertTrue(model.finishLoadForRender(generation, "user-a"))
        assertEquals(DashboardStatus.INITIAL, model.state.status)
        assertNull(model.state.headline)
        assertNull(model.state.riskLevel)
    }

    @Test
    fun oldQueuedFinalRenderCannotClearTheNewAccountsCompletedPayload() {
        val oldGeneration = model.markLoading()
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer { call ->
            risk(call.getArgument<String>(0))
        }
        model.load("user-a", "token", "profile", "en", pendingGeneration = oldGeneration)
        owner.set("user-b")
        val newGeneration = model.markLoading()
        model.load("user-b", "token", "profile", "en", pendingGeneration = newGeneration)
        assertFalse(model.finishLoadForRender(oldGeneration, "user-a"))
        assertTrue(model.finishLoadForRender(newGeneration, "user-b"))
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("user-b", model.state.headline)
    }

    @Test
    fun latePrimaryResponseAfterLogoutDoesNotRestoreStateOrInvokeReady() {
        var ready = 0
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer {
            owner.set(null)
            model.reset()
            risk("account A")
        }
        load("user-a", ready = { ready++ })
        assertEquals(DashboardStatus.INITIAL, model.state.status)
        assertNull(model.state.headline)
        assertEquals(0, ready)
        verify(api, never()).fetchWearableToday(anyString(), anyString())
    }

    @Test
    fun accountSwitchWithoutResetRejectsTheOldPrimaryResponse() {
        var ready = 0
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer {
            owner.set("user-b")
            risk("account A")
        }
        load("user-a", ready = { ready++ })
        assertEquals(DashboardStatus.INITIAL, model.state.status)
        assertNull(model.state.headline)
        assertEquals(0, ready)
    }

    @Test
    fun olderFailureCannotEraseACompletedReplacementLoad() {
        var oldReady = 0
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer { call ->
            if (call.getArgument<String>(0) == "user-a") {
                owner.set("user-b")
                load("user-b")
                throw IOException("old request failed")
            }
            risk("account B")
        }
        load("user-a", ready = { oldReady++ })
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account B", model.state.headline)
        assertEquals(0, oldReady)
    }

    @Test
    fun newerLoadForTheSameAccountWinsOverAnOlderResponse() {
        var oldReady = 0
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer { call ->
            if (call.getArgument<String>(2) == "old-profile") {
                load("user-a", "new-profile")
                risk("old profile")
            } else risk("new profile")
        }
        load("user-a", "old-profile", ready = { oldReady++ })
        assertEquals("new profile", model.state.headline)
        assertEquals(0, oldReady)
    }

    @Test
    fun lateWearableEnrichmentCannotOverwriteTheNextAccountsDashboard() {
        `when`(api.fetchCurrentRisk(anyString(), anyString(), anyString())).thenAnswer { call ->
            risk(call.getArgument<String>(0))
        }
        `when`(api.fetchWearableToday(anyString(), anyString())).thenAnswer { call ->
            if (call.getArgument<String>(0) == "user-a") {
                owner.set("user-b")
                load("user-b")
                """{"consent":{"isActive":true},"dailySummary":{"stepsTotal":999}}"""
            } else "{}"
        }
        load("user-a")
        assertEquals("user-b", model.state.headline)
        assertNull(model.state.wearableSteps)
        verify(api, never()).fetchHealthSummary(eqString("user-a"), anyString())
        verify(api, never()).fetchHazards(eqString("user-a"), anyString(), anyString())
    }

    @Test
    fun queuedOldAccountRequestCannotCancelTheNewAccountsInFlightLoad() {
        owner.set("user-b")
        `when`(api.fetchCurrentRisk(eqString("user-b"), anyString(), anyString())).thenAnswer {
            load("user-a")
            risk("account B")
        }
        load("user-b")
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account B", model.state.headline)
        verify(api, never()).fetchCurrentRisk(eqString("user-a"), anyString(), anyString())
    }

    @Test
    fun ownerSnapshotAndGenerationAllocationAreSerializedWithTheNewLoad() {
        val ownerRead = CountDownLatch(1)
        val releaseOldOwnerRead = CountDownLatch(1)
        val newLoadStarted = CountDownLatch(1)
        val newHttpStarted = CountDownLatch(1)
        val releaseNewHttp = CountDownLatch(1)
        val blockFirstRead = AtomicBoolean(true)
        val failure = AtomicReference<Throwable?>(null)
        ApiClient.configureAuth(provider = {
            val snapshot = owner.get()
            if (Thread.currentThread().name == "load-a" && blockFirstRead.getAndSet(false)) {
                ownerRead.countDown()
                check(releaseOldOwnerRead.await(5, TimeUnit.SECONDS))
            }
            snapshot?.let { ApiClient.AuthState(it, "token", "refresh") }
        }, updater = null)
        `when`(api.fetchCurrentRisk(eqString("user-b"), anyString(), anyString())).thenAnswer {
            newHttpStarted.countDown()
            check(releaseNewHttp.await(5, TimeUnit.SECONDS))
            risk("account B")
        }
        val oldLoad = Thread({
            try { load("user-a") } catch (error: Throwable) { failure.set(error) }
        }, "load-a")
        val newLoad = Thread({
            try {
                newLoadStarted.countDown()
                load("user-b")
            } catch (error: Throwable) { failure.set(error) }
        }, "load-b")
        try {
            oldLoad.start()
            assertTrue(ownerRead.await(5, TimeUnit.SECONDS))
            owner.set("user-b")
            newLoad.start()
            assertTrue(newLoadStarted.await(5, TimeUnit.SECONDS))
            // Before the fix B could enter HTTP while A held an old auth snapshot.
            // With a shared begin monitor B waits; both schedules are released below.
            newHttpStarted.await(250, TimeUnit.MILLISECONDS)
            releaseOldOwnerRead.countDown()
            oldLoad.join(5000)
            assertFalse(oldLoad.isAlive)
            assertTrue(newHttpStarted.await(5, TimeUnit.SECONDS))
        } finally {
            releaseOldOwnerRead.countDown()
            releaseNewHttp.countDown()
            oldLoad.join(5000)
            newLoad.join(5000)
        }
        failure.get()?.let { throw AssertionError("request worker failed", it) }
        assertFalse(newLoad.isAlive)
        assertEquals(DashboardStatus.SUCCESS, model.state.status)
        assertEquals("account B", model.state.headline)
    }
}
