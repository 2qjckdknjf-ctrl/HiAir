package com.hiair.analytics

import android.content.Context
import android.content.SharedPreferences
import com.hiair.ui.settings.SettingsViewModel
import java.time.LocalDate
import java.time.ZoneOffset
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.ArgumentMatchers.*
import org.mockito.Mockito.*

class ProductAnalyticsConsentTest {
    private val values = mutableMapOf<String, Any>()
    private val events = mutableListOf<String>()
    private lateinit var context: Context

    private fun signIn(settings: SettingsViewModel, userId: String) {
        settings.setUserId(userId)
        settings.setAccessToken("token-$userId")
    }

    @Before
    fun setUp() {
        val prefs = mock(SharedPreferences::class.java)
        val editor = mock(SharedPreferences.Editor::class.java)
        context = mock(Context::class.java)
        `when`(context.applicationContext).thenReturn(context)
        `when`(context.getSharedPreferences(anyString(), anyInt())).thenReturn(prefs)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(prefs.getBoolean(anyString(), anyBoolean())).thenAnswer { call ->
            values[call.getArgument<String>(0)] as? Boolean ?: call.getArgument<Boolean>(1)
        }
        `when`(prefs.getString(anyString(), isNull())).thenAnswer { call ->
            values[call.getArgument<String>(0)] as? String
        }
        `when`(editor.putBoolean(anyString(), anyBoolean())).thenAnswer { call ->
            values[call.getArgument<String>(0)] = call.getArgument<Boolean>(1)
            editor
        }
        `when`(editor.putString(anyString(), anyString())).thenAnswer { call ->
            values[call.getArgument<String>(0)] = call.getArgument<String>(1)
            editor
        }
        ProductAnalytics.bind(context)
        ProductAnalytics.testEventSink = { name, _ -> events.add(name) }
    }

    @After
    fun tearDown() {
        ProductAnalytics.bindAccount(null, null)
        ProductAnalytics.testEventSink = null
    }

    @Test
    fun legacyDeviceConsentAndCountersCannotAuthorizeAnAccount() {
        values["consent"] = true
        values["first_useful_sent"] = true
        val settings = SettingsViewModel()
        signIn(settings, "user-a")
        assertFalse(settings.state.productAnalyticsEnabled)
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        assertTrue(events.isEmpty())
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        assertEquals(listOf(ProductAnalytics.Event.FIRST_USEFUL_RECOMMENDATION), events)
    }

    @Test
    fun settingsCreatedBeforePreferencesLoadsTheRestoredAccountsConsent() {
        val settings = SettingsViewModel()
        values["consent.account.user-a"] = true
        ProductAnalytics.bind(context)
        assertFalse(settings.state.productAnalyticsEnabled)
        settings.setUserId("user-a")
        assertFalse(settings.state.productAnalyticsEnabled)
        assertFalse(ProductAnalytics.analyticsConsentGranted)
        settings.setAccessToken("token-user-a")
        assertTrue(settings.state.productAnalyticsEnabled)
        assertTrue(ProductAnalytics.analyticsConsentGranted)
        signIn(settings, "user-b")
        assertFalse(settings.state.productAnalyticsEnabled)
        assertFalse(ProductAnalytics.analyticsConsentGranted)
        signIn(settings, "user-a")
        assertTrue(settings.state.productAnalyticsEnabled)
        settings.resetSessionAfterLogout()
        assertFalse(settings.state.productAnalyticsEnabled)
        assertFalse(ProductAnalytics.analyticsConsentGranted)
    }

    @Test
    fun firstUsefulRecommendationIsDeduplicatedPerConsentingAccount() {
        val settings = SettingsViewModel()
        signIn(settings, "user-a")
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        settings.resetSessionAfterLogout()
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        signIn(settings, "user-b")
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        assertEquals(1, events.size)
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        assertEquals(2, events.size)
        signIn(settings, "user-a")
        ProductAnalytics.recordUsefulRecommendation("dashboard")
        assertEquals(2, events.size)
    }

    @Test
    fun lateAccountAResultCannotUseAccountBsConsentOrFirstUsefulMarker() {
        val settings = SettingsViewModel()
        signIn(settings, "user-b")
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        ProductAnalytics.recordUsefulRecommendation("dashboard", userId = "user-a")
        assertTrue(events.isEmpty())
        ProductAnalytics.recordUsefulRecommendation("dashboard", userId = "user-b")
        assertEquals(1, events.size)
    }

    @Test
    fun retentionDatesAreNotTransferredBetweenAccounts() {
        val settings = SettingsViewModel()
        signIn(settings, "user-a")
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        val older = LocalDate.now(ZoneOffset.UTC).minusDays(8).toString()
        values["first_open_day.account.user-a"] = older
        values["last_open_day.account.user-a"] = older
        signIn(settings, "user-b")
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        ProductAnalytics.recordAppOpen()
        assertTrue(events.isEmpty())
        signIn(settings, "user-a")
        ProductAnalytics.recordAppOpen()
        ProductAnalytics.recordAppOpen()
        assertEquals(listOf(ProductAnalytics.Event.REPEAT_USE, ProductAnalytics.Event.RETENTION_WINDOW), events)
    }

    @Test
    fun anonymousConsentCannotAuthorizeTheNextLogin() {
        val settings = SettingsViewModel()
        settings.setProductAnalyticsEnabled(true, userId = settings.state.userId)
        assertFalse(settings.state.productAnalyticsEnabled)
        signIn(settings, "user-b")
        assertFalse(ProductAnalytics.analyticsConsentGranted)
    }

    @Test
    fun staleRenderedToggleCannotChangeTheNewAccountsConsentOrDisplayedState() {
        val settings = SettingsViewModel()
        signIn(settings, "user-a")
        val renderedOwner = settings.state.userId
        val oldClick: (Boolean) -> Unit = { settings.setProductAnalyticsEnabled(it, userId = renderedOwner) }
        signIn(settings, "user-b")
        oldClick(true)
        assertFalse(ProductAnalytics.analyticsConsentGranted)
        assertFalse(settings.state.productAnalyticsEnabled)
        settings.setProductAnalyticsEnabled(true, userId = "user-b")
        oldClick(false)
        assertTrue(ProductAnalytics.analyticsConsentGranted)
        assertTrue(settings.state.productAnalyticsEnabled)
    }

    @Test
    fun partialRestoredIdentityCannotGrantConsentBeforeAuthentication() {
        val settings = SettingsViewModel()
        settings.setUserId("user-a")
        settings.setProductAnalyticsEnabled(true, userId = "user-a")
        assertFalse(settings.state.productAnalyticsEnabled)
        settings.setAccessToken("token-user-a")
        assertFalse(ProductAnalytics.analyticsConsentGranted)
        settings.setProductAnalyticsEnabled(true, userId = "user-a")
        settings.setAccessToken(" \n ")
        assertFalse(ProductAnalytics.analyticsConsentGranted)
        assertFalse(settings.state.productAnalyticsEnabled)
    }
}
