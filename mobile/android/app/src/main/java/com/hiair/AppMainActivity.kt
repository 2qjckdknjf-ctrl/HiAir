package com.hiair

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.AppScreen
import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.render.MainScreenRenderer
import com.hiair.ui.theme.V2Ui

@SuppressLint("SetTextI18n")
class AppMainActivity : AppCompatActivity() {
    private val rootShell = RootShellViewModel()
    private lateinit var sessionStore: SessionStore
    private lateinit var pushTokenRegistrar: PushTokenRegistrar
    private lateinit var titleView: TextView
    private lateinit var bodyContainer: LinearLayout
    private lateinit var screenRenderer: MainScreenRenderer
    private lateinit var dashboardButton: Button
    private lateinit var plannerButton: Button
    private lateinit var symptomsButton: Button
    private lateinit var settingsButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionStore = SessionStore(this)
        pushTokenRegistrar = PushTokenRegistrar(this)
        restoreSession()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(
                    Color.parseColor("#0B1220"),
                    Color.parseColor("#10203A"),
                    Color.parseColor("#0A1A34")
                )
            )
        }

        titleView = TextView(this).apply {
            text = AndroidL10n.t("title.dashboard", rootShell.settingsViewModel.state.preferredLanguage)
            textSize = 30f
            setTextColor(Color.parseColor("#EAF1FB"))
            setTypeface(typeface, Typeface.BOLD)
        }
        root.addView(titleView)

        val navRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            val p = dp(8)
            setPadding(p, p, p, p)
            background = V2Ui.cardBackground(this@AppMainActivity, "#10264A", strokeHex = "#2F4C77", radiusDp = 16)
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

        setContentView(root)
        renderCurrentScreen()
    }

    private fun restoreSession() {
        val stored = sessionStore.load()
        rootShell.settingsViewModel.setEmail(stored.email)
        rootShell.settingsViewModel.setUserId(stored.userId)
        rootShell.settingsViewModel.setAccessToken(stored.accessToken)
        rootShell.settingsViewModel.setProfileId(stored.profileId)
        rootShell.settingsViewModel.setPreferredLanguage(stored.preferredLanguage)
        rootShell.symptomLogViewModel.updateProfileId(stored.profileId)
        pushTokenRegistrar.registerIfTokenAvailable(stored, stored.profileId.ifBlank { null })
    }

    private fun persistSession() {
        val state = rootShell.settingsViewModel.state
        val session = StoredSession(
            email = state.email,
            userId = state.userId,
            accessToken = state.accessToken,
            profileId = state.profileId,
            preferredLanguage = state.preferredLanguage
        )
        sessionStore.save(session)
        pushTokenRegistrar.requestPermissionAndRegister(session, state.profileId.ifBlank { null })
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PushTokenRegistrar.REQUEST_POST_NOTIFICATIONS) {
            val session = sessionStore.load()
            pushTokenRegistrar.registerIfTokenAvailable(session, session.profileId.ifBlank { null })
        }
    }

    private fun renderCurrentScreen() {
        bodyContainer.removeAllViews()
        syncNavLabels()
        syncNavSelection()
        when (rootShell.state.currentScreen) {
            AppScreen.DASHBOARD -> if (rootShell.isAuthenticated()) screenRenderer.renderDashboard() else screenRenderer.renderSettings()
            AppScreen.PLANNER -> if (rootShell.isAuthenticated()) screenRenderer.renderPlanner() else screenRenderer.renderSettings()
            AppScreen.SYMPTOMS -> if (rootShell.isAuthenticated()) screenRenderer.renderSymptoms() else screenRenderer.renderSettings()
            AppScreen.SETTINGS -> screenRenderer.renderSettings()
        }
    }

    private fun syncNavLabels() {
        val lang = rootShell.settingsViewModel.state.preferredLanguage
        dashboardButton.text = AndroidL10n.t("nav.dashboard", lang)
        plannerButton.text = AndroidL10n.t("nav.planner", lang)
        symptomsButton.text = AndroidL10n.t("nav.symptoms", lang)
        settingsButton.text = AndroidL10n.t("nav.settings", lang)
    }

    private fun syncNavSelection() {
        val current = rootShell.state.currentScreen
        setNavSelected(dashboardButton, current == AppScreen.DASHBOARD)
        setNavSelected(plannerButton, current == AppScreen.PLANNER)
        setNavSelected(symptomsButton, current == AppScreen.SYMPTOMS)
        setNavSelected(settingsButton, current == AppScreen.SETTINGS)
    }

    private fun setNavSelected(button: Button, selected: Boolean) {
        if (selected) {
            button.background = V2Ui.cardBackground(this, "#2A4C7F", strokeHex = "#67C6FF", radiusDp = 13)
            button.setTextColor(Color.parseColor("#DDF4FF"))
        } else {
            button.background = V2Ui.cardBackground(this, "#1B3A62", strokeHex = "#325888", radiusDp = 13)
            button.setTextColor(Color.parseColor("#64D7FF"))
        }
    }

    private fun dp(value: Int): Int = V2Ui.dp(this, value)
}
