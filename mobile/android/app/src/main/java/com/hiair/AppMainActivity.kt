package com.hiair

import android.annotation.SuppressLint
import android.util.Log
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.hiair.StoreScreenshotBootstrap
import com.hiair.StoreScreenshotMode
import com.hiair.StoreScreenshotReadiness
import com.hiair.ui.i18n.AndroidL10n
import com.hiair.ui.navigation.AppScreen
import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirScreenMetrics
import com.hiair.ui.design.HiAirWindowLayout
import com.hiair.ui.design.TimeOfDayBackground
import com.hiair.ui.design.Tokens
import com.hiair.ui.design.markGeometry
import com.hiair.ui.accessibility.HiAirGeometryMarkers
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
import kotlinx.coroutines.launch
import com.hiair.ui.accessibility.HiAirScreenMarkers
import com.hiair.ui.design.HiAirV4Presentation
import com.hiair.ui.design.HiAirLiquidGlass
import androidx.annotation.VisibleForTesting
import com.hiair.ui.theme.V2Ui

@SuppressLint("SetTextI18n")
class AppMainActivity : AppCompatActivity(), WearableHealthHost, LocationBootstrapHost {
    private val rootShell = RootShellViewModel()
    private lateinit var sessionStore: SessionStore
    private lateinit var onboardingStore: OnboardingStore
    private lateinit var titleView: TextView
    private lateinit var contentFrame: FrameLayout
    private lateinit var bodyContainer: LinearLayout
    private lateinit var bodyHost: LinearLayout
    private lateinit var contentScroll: ScrollView
    private var scrollYBeforeReflow: Int = 0
    private lateinit var overlayContainer: FrameLayout
    private lateinit var screenRenderer: MainScreenRenderer
    private val paywallController = SubscriptionPaywallController(rootShell.settingsViewModel)
    private lateinit var dashboardButton: Button
    private lateinit var plannerButton: Button
    private lateinit var insightsButton: Button
    private lateinit var symptomsButton: Button
    private lateinit var settingsButton: Button
    private lateinit var navShell: FrameLayout
    private lateinit var navRow: LinearLayout
    private var storeScreenshotLayoutCommitted = false
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
            wearableHealthController.onAuthenticatedUserChanged(
                userId = oauthSession.userId,
                accountGeneration = sessionStore.accountGeneration(),
                accessToken = oauthSession.accessToken.ifBlank { null },
            )
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
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        root.addView(titleView)

        val contentFrameView = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            )
            markGeometry(HiAirGeometryMarkers.LAYOUT_CONTENT_FRAME)
        }
        contentFrame = contentFrameView
        val scroll = ScrollView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            clipToPadding = false
            markGeometry(HiAirGeometryMarkers.LAYOUT_CONTENT_SCROLL)
        }
        contentScroll = scroll
        bodyContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, dp(108))
            markGeometry(HiAirGeometryMarkers.LAYOUT_BODY_CONTAINER)
        }
        val bodyHostView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER_HORIZONTAL
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            )
            addView(bodyContainer)
        }
        bodyHost = bodyHostView
        scroll.addView(bodyHostView)
        overlayContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            isClickable = false
            isFocusable = false
        }
        contentFrameView.addView(scroll)
        contentFrameView.addView(overlayContainer)
        root.addView(contentFrameView)

        navRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            val p = dp(8)
            setPadding(p, p, p, p + dp(4))
            markGeometry(HiAirGeometryMarkers.NAV_ROW)
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
        navShell = HiAirLiquidGlass.wrapNavigationContent(
            this,
            HiAirComponents.liquidGlassNavBackground(this),
            navRow,
        ).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            markGeometry(HiAirGeometryMarkers.NAV_BAR)
        }
        root.addView(navShell)

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
        attachNavTailPaddingListener()
        FirstRunOnboardingRenderer.resetStepForSession(
            rootShell.settingsViewModel.state.userId.isNotBlank() &&
                rootShell.settingsViewModel.state.accessToken.isNotBlank(),
        )
        StoreScreenshotBootstrap.apply(intent, rootShell, onboardingStore)
        renderCurrentScreen()
        scheduleStoreScreenshotLayoutPassIfNeeded()
        if (StoreScreenshotMode.active) {
            ScreenshotEnvironmentReporter.reportIfNeeded(
                context = this,
                captureOut = intent?.getStringExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_OUT),
                runId = intent?.getStringExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID),
            )
        }
        if (rootShell.settingsViewModel.state.userId.isNotBlank() && !StoreScreenshotMode.active) {
            rootShell.settingsViewModel.refreshEntitlement { runOnUiThread { renderCurrentScreen() } }
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
        // Bind restored identity immediately so durable revoke/delete tombstones
        // retry on cold start with this account's token (never another user's).
        wearableHealthController.onAuthenticatedUserChanged(
            userId = stored.userId,
            accountGeneration = sessionStore.accountGeneration(),
            accessToken = stored.accessToken.ifBlank { null },
        )
    }

    private fun persistSession() {
        val state = rootShell.settingsViewModel.state
        sessionStore.save(
            StoredSession(
                email = state.email,
                userId = state.userId,
                accessToken = state.accessToken,
                refreshToken = state.refreshToken,
                profileId = state.profileId
            )
        )
        wearableHealthController.onAuthenticatedUserChanged(
            userId = state.userId,
            accountGeneration = sessionStore.accountGeneration(),
            accessToken = state.accessToken.ifBlank { null },
        )
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        scrollYBeforeReflow = contentScroll.scrollY
        screenRenderer.runPresentationOnly {
            renderCurrentScreen()
        }
        contentScroll.post { contentScroll.scrollTo(0, scrollYBeforeReflow) }
        if (StoreScreenshotMode.active) {
            scheduleStoreScreenshotLayoutPassIfNeeded()
        } else {
            updateResponsiveChrome()
        }
    }

    private var navTailPaddingListenerAttached = false

    private fun attachNavTailPaddingListener() {
        if (navTailPaddingListenerAttached) return
        navTailPaddingListenerAttached = true
        navShell.viewTreeObserver.addOnGlobalLayoutListener(
            object : android.view.ViewTreeObserver.OnGlobalLayoutListener {
                override fun onGlobalLayout() {
                    if (navShell.height <= 0) return
                    val tailPad = HiAirV4Presentation.scrollTailPaddingPx(this@AppMainActivity, navShell)
                    if (bodyContainer.paddingBottom != tailPad) {
                        bodyContainer.setPadding(0, dp(12), 0, tailPad)
                    }
                }
            },
        )
    }

    private fun updateResponsiveChrome() {
        val snapshot = HiAirWindowLayout.snapshotForActivity(this)
        HiAirWindowLayout.applyContentWidth(bodyContainer, snapshot)
        val navMaxPx = V2Ui.dp(this, HiAirScreenMetrics.navBarMaxWidthDp.coerceAtMost(snapshot.innerAvailableWidthDp))
        val navParams = navShell.layoutParams as LinearLayout.LayoutParams
        navParams.width = minOf(navMaxPx, snapshot.safeAvailableWidthPx).coerceAtLeast(0)
        navParams.gravity = android.view.Gravity.CENTER_HORIZONTAL
        navShell.layoutParams = navParams
        HiAirV4Presentation.applyTitleAxisAlignment(titleView, this)
        val tailPad = HiAirV4Presentation.scrollTailPaddingPx(this, navShell)
        bodyContainer.setPadding(0, dp(12), 0, tailPad)
    }

    private fun applyStoreScreenshotScrollContract() {
        val centerPortraitOnboarding = StoreScreenshotMode.active &&
            StoreScreenshotMode.targetScreen == "onboarding" &&
            HiAirV4Presentation.shouldCenterOnboardingPortrait(this)
        contentScroll.isFillViewport = centerPortraitOnboarding
        val hostHeight = if (centerPortraitOnboarding) {
            FrameLayout.LayoutParams.MATCH_PARENT
        } else {
            FrameLayout.LayoutParams.WRAP_CONTENT
        }
        (bodyHost.layoutParams as FrameLayout.LayoutParams).height = hostHeight
        bodyContainer.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            if (centerPortraitOnboarding) LinearLayout.LayoutParams.MATCH_PARENT else LinearLayout.LayoutParams.WRAP_CONTENT,
        )
    }

    private fun renderCurrentScreen() {
        StoreScreenshotReadiness.clear(bodyContainer)
        bodyContainer.removeAllViews()
        overlayContainer.removeAllViews()
        updateResponsiveChrome()
        applyStoreScreenshotScrollContract()
        syncNavLabels()
        syncNavSelection()
        updateChromeVisibility()
        if (rootShell.settingsViewModel.state.showPaywall) {
            screenRenderer.renderPaywall(paywallController)
            publishStoreScreenshotReadiness()
            return
        }
        if (!onboardingStore.isCompleted() &&
            rootShell.state.currentScreen == com.hiair.ui.navigation.AppScreen.DASHBOARD
        ) {
            screenRenderer.renderFirstRun(onboardingStore)
            publishStoreScreenshotReadiness()
            return
        }
        when (rootShell.state.currentScreen) {
            AppScreen.DASHBOARD -> screenRenderer.renderDashboard()
            AppScreen.PLANNER -> screenRenderer.renderPlanner()
            AppScreen.INSIGHTS -> screenRenderer.renderInsights()
            AppScreen.SYMPTOMS -> screenRenderer.renderSymptoms()
            AppScreen.SETTINGS -> screenRenderer.renderSettings()
        }
        publishStoreScreenshotReadiness()
        if (StoreScreenshotMode.active) {
            bodyContainer.post {
                logStoreScreenshotLayoutTrace("renderCurrentScreen")
                publishStoreScreenshotReadiness()
            }
        }
    }

    private fun scheduleStoreScreenshotLayoutPassIfNeeded() {
        if (!StoreScreenshotMode.active) return
        bodyContainer.post {
            if (storeScreenshotLayoutCommitted) {
                publishStoreScreenshotReadiness()
                return@post
            }
            if (bodyContainer.width <= 0 || bodyContainer.height <= 0) {
                bodyContainer.viewTreeObserver.addOnGlobalLayoutListener(
                    object : android.view.ViewTreeObserver.OnGlobalLayoutListener {
                        override fun onGlobalLayout() {
                            if (bodyContainer.width <= 0 || bodyContainer.height <= 0) return
                            bodyContainer.viewTreeObserver.removeOnGlobalLayoutListener(this)
                            commitStoreScreenshotLayoutPass()
                        }
                    },
                )
                return@post
            }
            commitStoreScreenshotLayoutPass()
        }
    }

    private fun commitStoreScreenshotLayoutPass() {
        if (!StoreScreenshotMode.active || storeScreenshotLayoutCommitted) return
        storeScreenshotLayoutCommitted = true
        updateResponsiveChrome()
        if (bodyContainer.childCount == 0) {
            renderCurrentScreen()
        } else {
            bodyContainer.requestLayout()
        }
        bodyContainer.post {
            logStoreScreenshotLayoutTrace("commitStoreScreenshotLayoutPass")
            publishStoreScreenshotReadiness()
        }
    }

    private fun logStoreScreenshotLayoutTrace(stage: String) {
        if (!BuildConfig.DEBUG || !StoreScreenshotMode.active) return
        val root = contentFrame.rootView
        val contentLoc = IntArray(2)
        val navLoc = IntArray(2)
        contentFrame.getLocationOnScreen(contentLoc)
        navShell.getLocationOnScreen(navLoc)
        Log.d(
            TAG_STORE_LAYOUT,
            buildString {
                append("stage=$stage ")
                append("renderer=entered ")
                append("bodyChildCount=${bodyContainer.childCount} ")
                append("bodyMeasured=${bodyContainer.measuredWidth}x${bodyContainer.measuredHeight} ")
                append("contentFrameMeasured=${contentFrame.measuredWidth}x${contentFrame.measuredHeight} ")
                append("contentScrollMeasured=${contentScroll.measuredWidth}x${contentScroll.measuredHeight} ")
                append("navShellMeasured=${navShell.measuredWidth}x${navShell.measuredHeight} ")
                append("navRowMeasured=${navRow.measuredWidth}x${navRow.measuredHeight} ")
                append("rootMeasured=${root.measuredWidth}x${root.measuredHeight} ")
                append("contentFrameBounds=[${contentLoc[0]},${contentLoc[1]}][")
                append(contentLoc[0] + contentFrame.width)
                append(',')
                append(contentLoc[1] + contentFrame.height)
                append("] ")
                append("navShellBounds=[${navLoc[0]},${navLoc[1]}][")
                append(navLoc[0] + navShell.width)
                append(',')
                append(navLoc[1] + navShell.height)
                append(']')
            },
        )
    }

    private fun publishStoreScreenshotReadiness() {
        if (!StoreScreenshotMode.active) return
        StoreScreenshotReadiness.publish(
            targetScreen = StoreScreenshotMode.targetScreen,
            bodyContainer = bodyContainer,
            titleView = titleView,
            rootShell = rootShell,
            navShell = navShell,
            contentFrame = contentFrame,
            contentScroll = contentScroll,
            navRow = navRow,
        )
    }

    private fun isAuthenticated(): Boolean {
        val state = rootShell.settingsViewModel.state
        return state.userId.isNotBlank() && state.accessToken.isNotBlank()
    }

    private fun shouldShowMainNavigation(): Boolean {
        return isAuthenticated() && onboardingStore.isCompleted()
    }

    private fun updateChromeVisibility() {
        val showNav = shouldShowMainNavigation() && !rootShell.settingsViewModel.state.showPaywall
        navShell.visibility = if (showNav) android.view.View.VISIBLE else android.view.View.GONE
        titleView.visibility = if (showNav) android.view.View.VISIBLE else android.view.View.GONE
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

    @VisibleForTesting
    internal fun bodyContainerForTests(): LinearLayout = bodyContainer

    @VisibleForTesting
    internal fun contentFrameForTests(): FrameLayout = contentFrame

    @VisibleForTesting
    internal fun contentScrollForTests(): ScrollView = contentScroll

    @VisibleForTesting
    internal fun navRowForTests(): LinearLayout = navRow

    @VisibleForTesting
    internal fun titleViewForTests(): TextView = titleView

    @VisibleForTesting
    internal fun rootViewForTests(): android.view.View = contentFrame.rootView

    @VisibleForTesting
    internal fun rootShellForTests(): com.hiair.ui.navigation.RootShellViewModel = rootShell

    @VisibleForTesting
    internal fun navShellForTests(): FrameLayout = navShell

    companion object {
        const val TAG_STORE_LAYOUT = "HiAirStoreLayout"
    }

    @VisibleForTesting
    internal fun windowLayoutSnapshotForTests(): com.hiair.ui.design.HiAirWindowLayoutSnapshot =
        HiAirWindowLayout.snapshotForActivity(this)

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

    override fun revokeWearablesLocalFirst(deleteData: Boolean, onComplete: (Boolean) -> Unit) {
        val state = rootShell.settingsViewModel.state
        lifecycleScope.launch {
            val ok = wearableHealthController.revokeLocalFirst(
                userId = state.userId,
                accessToken = state.accessToken.ifBlank { null },
                deleteData = deleteData,
            )
            onComplete(ok)
        }
    }

    override fun bootstrapLocation(onComplete: () -> Unit) {
        locationController.bootstrapLocation(onComplete)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (StoreScreenshotBootstrap.reapplyIfNeeded(intent, rootShell, onboardingStore)) {
            storeScreenshotLayoutCommitted = false
            renderCurrentScreen()
            scheduleStoreScreenshotLayoutPassIfNeeded()
            return
        }
        val oauthSession = supabaseAuth.consumeOAuthCallback(intent) ?: return
        rootShell.settingsViewModel.setEmail(oauthSession.email)
        rootShell.settingsViewModel.setUserId(oauthSession.userId)
        rootShell.settingsViewModel.setAccessToken(oauthSession.accessToken)
        rootShell.settingsViewModel.setRefreshToken(oauthSession.refreshToken)
        persistSession()
        renderCurrentScreen()
    }
}
