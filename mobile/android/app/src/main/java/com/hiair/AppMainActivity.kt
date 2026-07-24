package com.hiair

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.OnboardingStore
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.AppScreen
import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirLiquidGlass
import com.hiair.ui.design.TimeOfDayBackground
import com.hiair.ui.design.Tokens
import com.hiair.network.ApiClient
import com.hiair.network.SupabaseAuthService
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.health.HealthConnectService
import com.hiair.health.WearableHealthController
import com.hiair.health.WearableHealthHost
import com.hiair.location.LocationBootstrapHost
import com.hiair.location.LocationController
import com.hiair.ui.render.MainScreenRenderer
import com.hiair.ui.render.FirstRunOnboardingRenderer
import com.hiair.ui.theme.V2Ui

@SuppressLint("SetTextI18n")
class AppMainActivity : AppCompatActivity(), WearableHealthHost, LocationBootstrapHost {
    private val rootShell = RootShellViewModel()
    private lateinit var sessionStore: SessionStore
    private lateinit var onboardingStore: OnboardingStore
    private lateinit var titleView: TextView
    private lateinit var bodyContainer: LinearLayout
    private lateinit var overlayContainer: FrameLayout
    private lateinit var screenRenderer: MainScreenRenderer
    private val paywallController = SubscriptionPaywallController(rootShell.settingsViewModel)
    private lateinit var dashboardButton: Button
    private lateinit var plannerButton: Button
    private lateinit var insightsButton: Button
    private lateinit var symptomsButton: Button
    private lateinit var settingsButton: Button
    private lateinit var supabaseAuth: SupabaseAuthService
    private lateinit var healthConnectService: HealthConnectService
    private lateinit var wearableHealthController: WearableHealthController
    private lateinit var locationController: LocationController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionStore = SessionStore(this)
        onboardingStore = OnboardingStore(this)
        rootShell.symptomLogViewModel.attachFavoritesStore(SymptomFavoritesStore(this))
        healthConnectService = HealthConnectService(this)
        wearableHealthController = WearableHealthController(this, healthConnectService)
        locationController = LocationController(this, rootShell.settingsViewModel)
        supabaseAuth = SupabaseAuthService(this, sessionStore)
        rootShell.settingsViewModel.configureSupabaseAuth(supabaseAuth)
        restoreSession()
        supabaseAuth.consumeOAuthCallback(intent)?.let { oauthSession ->
            rootShell.settingsViewModel.setEmail(oauthSession.email)
            rootShell.settingsViewModel.setUserId(oauthSession.userId)
            rootShell.settingsViewModel.setAccessToken(oauthSession.accessToken)
            rootShell.settingsViewModel.setRefreshToken(oauthSession.refreshToken)
        }
        ApiClient.configureAuth(
            provider = {
                val state = rootShell.settingsViewModel.state
                if (state.userId.isBlank() || state.accessToken.isBlank() || state.refreshToken.isBlank()) {
                    null
                } else {
                    ApiClient.AuthState(
                        userId = state.userId,
                        accessToken = state.accessToken,
                        refreshToken = state.refreshToken
                    )
                }
            },
            updater = { refreshed ->
                runOnUiThread {
                    if (refreshed == null) {
                        rootShell.settingsViewModel.setUserId("")
                        rootShell.settingsViewModel.setAccessToken("")
                        rootShell.settingsViewModel.setRefreshToken("")
                        rootShell.settingsViewModel.setProfileId("")
                        rootShell.dashboardViewModel.reset()
                        rootShell.settingsViewModel.notifySessionExpired()
                        rootShell.openSettings()
                    } else {
                        rootShell.settingsViewModel.setUserId(refreshed.userId)
                        rootShell.settingsViewModel.setAccessToken(refreshed.accessToken)
                        rootShell.settingsViewModel.setRefreshToken(refreshed.refreshToken)
                    }
                    persistSession()
                    renderCurrentScreen()
                }
            },
            refresher = { state ->
                try {
                    val refreshed = supabaseAuth.refresh(state.refreshToken)
                    ApiClient.AuthState(
                        userId = refreshed.userId,
                        accessToken = refreshed.accessToken,
                        refreshToken = refreshed.refreshToken
                    )
                } catch (_: Exception) {
                    null
                }
            },
        )

        val horizontalPad = HiAirComponents.horizontalPaddingDp(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(horizontalPad, horizontalPad, horizontalPad, horizontalPad)
            background = TimeOfDayBackground.pageGradient()
        }

        titleView = TextView(this).apply {
            text = AndroidL10n.t("title.dashboard", rootShell.settingsViewModel.state.preferredLanguage)
            textSize = 30f
            setTextColor(Tokens.Text.primary)
            setTypeface(typeface, Typeface.BOLD)
        }
        root.addView(titleView)

        val navRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            val p = dp(8)
            setPadding(p, p, p, p)
            background = HiAirComponents.liquidGlassNavBackground(this@AppMainActivity)
            HiAirLiquidGlass.applyNavigationBlur(this)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.topMargin = dp(12)
            layoutParams = params
        }
        val lang = rootShell.settingsViewModel.state.preferredLanguage
        dashboardButton = V2Ui.navButton(this, AndroidL10n.t("nav.dashboard", lang)) {
            rootShell.openDashboard()
            renderCurrentScreen()
        }
        plannerButton = V2Ui.navButton(this, AndroidL10n.t("nav.planner", lang)) {
            rootShell.openPlanner()
            renderCurrentScreen()
        }
        insightsButton = V2Ui.navButton(this, AndroidL10n.t("nav.insights", lang)) {
            rootShell.openInsights()
            renderCurrentScreen()
        }
        symptomsButton = V2Ui.navButton(this, AndroidL10n.t("nav.symptoms", lang)) {
            rootShell.openSymptoms()
            renderCurrentScreen()
        }
        settingsButton = V2Ui.navButton(this, AndroidL10n.t("nav.settings", lang)) {
            rootShell.openSettings()
            renderCurrentScreen()
        }
        navRow.addView(dashboardButton)
        navRow.addView(plannerButton)
        navRow.addView(insightsButton)
        navRow.addView(symptomsButton)
        navRow.addView(settingsButton)
        root.addView(navRow)

        val contentFrame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            )
        }
        val scroll = ScrollView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
        }
        bodyContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, dp(24))
        }
        scroll.addView(bodyContainer)
        overlayContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            isClickable = false
            isFocusable = false
        }
        contentFrame.addView(scroll)
        contentFrame.addView(overlayContainer)
        root.addView(contentFrame)

        screenRenderer = MainScreenRenderer(
            activity = this,
            rootShell = rootShell,
            titleView = titleView,
            bodyContainer = bodyContainer,
            overlayContainer = overlayContainer,
            persistSession = ::persistSession,
            clearSession = {
                wearableHealthController.cancelPendingOperations()
                sessionStore.clear()
                rootShell.settingsViewModel.clearEntitlementState()
            },
            rerender = ::renderCurrentScreen
        )

        paywallController.onEntitlementUpdated = { renderCurrentScreen() }

        setContentView(root)
        FirstRunOnboardingRenderer.resetStepForSession(
            rootShell.settingsViewModel.state.userId.isNotBlank() &&
                rootShell.settingsViewModel.state.accessToken.isNotBlank(),
        )
        renderCurrentScreen()
        if (rootShell.settingsViewModel.state.userId.isNotBlank()) {
            rootShell.settingsViewModel.refreshEntitlement { renderCurrentScreen() }
        }
    }

    override fun onDestroy() {
        paywallController.destroy()
        super.onDestroy()
    }

    private fun restoreSession() {
        val stored = sessionStore.load()
        rootShell.settingsViewModel.setEmail(stored.email)
        rootShell.settingsViewModel.setUserId(stored.userId)
        rootShell.settingsViewModel.setAccessToken(stored.accessToken)
        rootShell.settingsViewModel.setRefreshToken(stored.refreshToken)
        rootShell.settingsViewModel.setProfileId(stored.profileId)
    }

    private fun persistSession() {
        val state = rootShell.settingsViewModel.state
        wearableHealthController.onAuthenticatedUserChanged(state.userId)
        sessionStore.save(
            StoredSession(
                email = state.email,
                userId = state.userId,
                accessToken = state.accessToken,
                refreshToken = state.refreshToken,
                profileId = state.profileId
            )
        )
    }

    private fun renderCurrentScreen() {
        bodyContainer.removeAllViews()
        overlayContainer.removeAllViews()
        syncNavLabels()
        syncNavSelection()
        if (rootShell.settingsViewModel.state.showPaywall) {
            screenRenderer.renderPaywall(paywallController)
            return
        }
        if (!onboardingStore.isCompleted() &&
            rootShell.state.currentScreen == com.hiair.ui.navigation.AppScreen.DASHBOARD
        ) {
            screenRenderer.renderFirstRun(onboardingStore)
            return
        }
        when (rootShell.state.currentScreen) {
            AppScreen.DASHBOARD -> screenRenderer.renderDashboard()
            AppScreen.PLANNER -> screenRenderer.renderPlanner()
            AppScreen.INSIGHTS -> screenRenderer.renderInsights()
            AppScreen.SYMPTOMS -> screenRenderer.renderSymptoms()
            AppScreen.SETTINGS -> screenRenderer.renderSettings()
        }
    }

    private fun syncNavLabels() {
        val lang = rootShell.settingsViewModel.state.preferredLanguage
        dashboardButton.text = AndroidL10n.t("nav.dashboard", lang)
        plannerButton.text = AndroidL10n.t("nav.planner", lang)
        insightsButton.text = AndroidL10n.t("nav.insights", lang)
        symptomsButton.text = AndroidL10n.t("nav.symptoms", lang)
        settingsButton.text = AndroidL10n.t("nav.settings", lang)
    }

    private fun syncNavSelection() {
        val current = rootShell.state.currentScreen
        setNavSelected(dashboardButton, current == AppScreen.DASHBOARD)
        setNavSelected(plannerButton, current == AppScreen.PLANNER)
        setNavSelected(insightsButton, current == AppScreen.INSIGHTS)
        setNavSelected(symptomsButton, current == AppScreen.SYMPTOMS)
        setNavSelected(settingsButton, current == AppScreen.SETTINGS)
    }

    private fun setNavSelected(button: Button, selected: Boolean) {
        button.background = HiAirComponents.navChipBackground(this, selected)
        button.setTextColor(if (selected) Tokens.Text.primary else Tokens.Cta.start)
    }

    private fun dp(value: Int): Int = V2Ui.dp(this, value)

    override fun requestWearableConnect(onComplete: () -> Unit) {
        val state = rootShell.settingsViewModel.state
        wearableHealthController.requestConnect(
            userId = state.userId,
            accessToken = state.accessToken.ifBlank { null },
            onComplete = onComplete,
        )
    }

    override fun syncWearablesIfPermitted() {
        val state = rootShell.settingsViewModel.state
        wearableHealthController.syncIfPermitted(
            userId = state.userId,
            accessToken = state.accessToken.ifBlank { null },
        )
    }

    override fun bootstrapLocation(onComplete: () -> Unit) {
        locationController.bootstrapLocation(onComplete)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val oauthSession = supabaseAuth.consumeOAuthCallback(intent) ?: return
        rootShell.settingsViewModel.setEmail(oauthSession.email)
        rootShell.settingsViewModel.setUserId(oauthSession.userId)
        rootShell.settingsViewModel.setAccessToken(oauthSession.accessToken)
        rootShell.settingsViewModel.setRefreshToken(oauthSession.refreshToken)
        persistSession()
        renderCurrentScreen()
    }
}
