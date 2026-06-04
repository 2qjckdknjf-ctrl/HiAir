package com.hiair

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.AppScreen
import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.TimeOfDayBackground
import com.hiair.ui.design.Tokens
import com.hiair.network.ApiClient
import com.hiair.network.SupabaseAuthService
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.render.MainScreenRenderer
import com.hiair.ui.theme.V2Ui

@SuppressLint("SetTextI18n")
class AppMainActivity : AppCompatActivity() {
    private val rootShell = RootShellViewModel()
    private lateinit var sessionStore: SessionStore
    private lateinit var titleView: TextView
    private lateinit var bodyContainer: LinearLayout
    private lateinit var screenRenderer: MainScreenRenderer
    private val paywallController = SubscriptionPaywallController(rootShell.settingsViewModel)
    private lateinit var dashboardButton: Button
    private lateinit var plannerButton: Button
    private lateinit var insightsButton: Button
    private lateinit var symptomsButton: Button
    private lateinit var settingsButton: Button
    private lateinit var supabaseAuth: SupabaseAuthService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionStore = SessionStore(this)
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
            background = HiAirComponents.glassCardBackground(this@AppMainActivity)
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

        val scroll = ScrollView(this)
        bodyContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, dp(24))
        }
        scroll.addView(bodyContainer)
        root.addView(scroll)

        screenRenderer = MainScreenRenderer(
            activity = this,
            rootShell = rootShell,
            titleView = titleView,
            bodyContainer = bodyContainer,
            persistSession = ::persistSession,
            clearSession = { sessionStore.clear() },
            rerender = ::renderCurrentScreen
        )

        paywallController.onEntitlementUpdated = { renderCurrentScreen() }

        setContentView(root)
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
    }

    private fun persistSession() {
        val state = rootShell.settingsViewModel.state
        sessionStore.save(
            StoredSession(
                email = state.email,
                userId = state.userId,
                accessToken = state.accessToken,
                refreshToken = state.refreshToken
            )
        )
    }

    private fun renderCurrentScreen() {
        bodyContainer.removeAllViews()
        syncNavLabels()
        syncNavSelection()
        if (rootShell.settingsViewModel.state.showPaywall) {
            screenRenderer.renderPaywall(paywallController)
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
