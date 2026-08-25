package com.hiair

import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.DashboardStatus
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.accessibility.HiAirScreenMarkers
import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.symptoms.SymptomLogState

/** DEBUG-only readiness markers for store-shot capture (fail-closed). */
object StoreScreenshotReadiness {
    private const val TAG = "HiAirStoreReady"
    private const val READY_BEACON_TAG = "hiair.store.ready_beacon"

    const val DASHBOARD = "store.dashboard.ready"
    const val PLANNER = "store.planner.ready"
    const val INSIGHTS = "store.insights.ready"
    const val SYMPTOMS = "store.symptoms.ready"
    const val SETTINGS = "store.settings.ready"
    const val PAYWALL = "store.paywall.ready"
    const val ONBOARDING = "store.onboarding.ready"
    const val NAVIGATION = "store.navigation.ready"

    const val DASHBOARD_CONTENT_ROOT = "store.dashboard.content_root"
    const val PLANNER_CONTENT_ROOT = "store.planner.content_root"
    const val INSIGHTS_CONTENT_ROOT = "store.insights.content_root"
    const val SYMPTOMS_CONTENT_ROOT = "store.symptoms.content_root"
    const val SETTINGS_CONTENT_ROOT = "store.settings.content_root"
    const val PAYWALL_CONTENT_ROOT = "store.paywall.content_root"
    const val ONBOARDING_CONTENT_ROOT = "store.onboarding.content_root"
    const val NAVIGATION_CONTENT_ROOT = "store.navigation.content_root"

    private val CONTENT_ROOTS = setOf(
        DASHBOARD_CONTENT_ROOT,
        PLANNER_CONTENT_ROOT,
        INSIGHTS_CONTENT_ROOT,
        SYMPTOMS_CONTENT_ROOT,
        SETTINGS_CONTENT_ROOT,
        PAYWALL_CONTENT_ROOT,
        ONBOARDING_CONTENT_ROOT,
        NAVIGATION_CONTENT_ROOT,
    )

    private val MAIN_TAB_TARGETS = setOf(
        "dashboard",
        "planner",
        "insights",
        "symptoms",
        "settings",
        "navigation",
    )

    private val MODAL_TARGETS = setOf("paywall", "onboarding")

    fun markerForTarget(target: String?): String? = when (target?.lowercase()) {
        "dashboard" -> DASHBOARD
        "planner" -> PLANNER
        "insights" -> INSIGHTS
        "symptoms" -> SYMPTOMS
        "settings" -> SETTINGS
        "paywall" -> PAYWALL
        "onboarding" -> ONBOARDING
        "navigation" -> NAVIGATION
        else -> null
    }

    fun contentRootForTarget(target: String?): String? = when (target?.lowercase()) {
        "dashboard" -> DASHBOARD_CONTENT_ROOT
        "planner" -> PLANNER_CONTENT_ROOT
        "insights" -> INSIGHTS_CONTENT_ROOT
        "symptoms" -> SYMPTOMS_CONTENT_ROOT
        "settings" -> SETTINGS_CONTENT_ROOT
        "paywall" -> PAYWALL_CONTENT_ROOT
        "onboarding" -> ONBOARDING_CONTENT_ROOT
        "navigation" -> NAVIGATION_CONTENT_ROOT
        else -> null
    }

    fun clear(bodyContainer: LinearLayout) {
        bodyContainer.contentDescription = null
        clearReadiness(bodyContainer)
    }

    fun publish(
        targetScreen: String?,
        bodyContainer: LinearLayout,
        titleView: TextView,
        rootShell: RootShellViewModel,
        navShell: View?,
        contentFrame: View? = null,
        contentScroll: View? = null,
        navRow: View? = null,
    ) {
        if (!BuildConfig.DEBUG || !StoreScreenshotMode.active) return
        clearReadiness(bodyContainer)
        // Keep screen-root ownership on body; never reuse it for store.*.ready.
        bodyContainer.contentDescription = null

        val marker = markerForTarget(targetScreen) ?: return
        if (!validateRootShellLayout(
                targetScreen = targetScreen,
                bodyContainer = bodyContainer,
                titleView = titleView,
                contentFrame = contentFrame,
                contentScroll = contentScroll,
                navShell = navShell,
                navRow = navRow,
            )
        ) {
            logReject(targetScreen, "root_shell_layout")
            return
        }
        val ready = when (targetScreen?.lowercase()) {
            "symptoms" -> validateSymptoms(bodyContainer, titleView, rootShell.symptomLogViewModel.state)
            "dashboard" -> validateDashboard(bodyContainer, titleView, rootShell)
            "planner" -> validatePlanner(bodyContainer, titleView, rootShell)
            "insights" -> validateInsights(bodyContainer)
            "settings" -> validateSettings(bodyContainer)
            "paywall" -> validatePaywall(bodyContainer)
            "onboarding" -> validateOnboarding(bodyContainer, navShell)
            "navigation" -> validateNavigation(bodyContainer, navShell)
            else -> false
        }
        if (!ready) {
            logReject(targetScreen, "screen_contract")
            return
        }

        val contentRoot = findContentRoot(bodyContainer, targetScreen)
        if (contentRoot == null || contentRoot === bodyContainer) {
            logReject(targetScreen, "missing_dedicated_content_root")
            return
        }
        HiAirScreenMarkers.forScreen(targetScreen)?.let { screenRoot ->
            bodyContainer.contentDescription = screenRoot
        }
        // Keep content-root ownership distinct from readiness marker.
        val expectedRoot = contentRootForTarget(targetScreen)
        if (expectedRoot != null) {
            contentRoot.contentDescription = expectedRoot
        }
        val beacon = ensureReadinessBeacon(contentRoot)
        beacon.contentDescription = marker
        Log.d(
            TAG,
            "ready target=$targetScreen marker=$marker contentRoot=${contentRoot.javaClass.simpleName}",
        )
    }

    private fun ensureReadinessBeacon(contentRoot: View): View {
        if (contentRoot is ViewGroup) {
            for (i in 0 until contentRoot.childCount) {
                val child = contentRoot.getChildAt(i)
                val desc = child.contentDescription?.toString().orEmpty()
                if (desc.startsWith("store.") && desc.endsWith(".ready")) {
                    return child
                }
                if (child.tag == READY_BEACON_TAG) return child
            }
            val beacon = View(contentRoot.context).apply {
                tag = READY_BEACON_TAG
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
                // Keep a tiny always-on-screen hit target at the top of the content root so
                // uiautomator dump includes store.*.ready even when body content is long.
                layoutParams = ViewGroup.LayoutParams(2, 2)
                minimumWidth = 2
                minimumHeight = 2
            }
            contentRoot.addView(beacon, 0)
            return beacon
        }
        return contentRoot
    }

    private fun clearReadiness(root: View) {
        val desc = root.contentDescription?.toString().orEmpty()
        if (desc.startsWith("store.") && desc.endsWith(".ready")) {
            root.contentDescription = null
        }
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                clearReadiness(root.getChildAt(i))
            }
        }
    }

    private fun validateRootShellLayout(
        targetScreen: String?,
        bodyContainer: LinearLayout,
        titleView: TextView,
        contentFrame: View?,
        contentScroll: View?,
        navShell: View?,
        navRow: View?,
    ): Boolean {
        if (contentFrame == null || contentScroll == null || navShell == null || navRow == null) {
            return true
        }
        if (bodyContainer.childCount <= 0) return false
        if (contentFrame.height <= 0 || contentScroll.height <= 0 || bodyContainer.width <= 0) {
            return false
        }
        val root = contentFrame.rootView
        val rootInnerHeight = root.height - root.paddingTop - root.paddingBottom
        if (rootInnerHeight <= 0) return false

        val target = targetScreen?.lowercase().orEmpty()
        return when {
            target in MODAL_TARGETS -> validateModalShell(
                titleView = titleView,
                contentFrame = contentFrame,
                navShell = navShell,
                rootInnerHeight = rootInnerHeight,
            )
            target in MAIN_TAB_TARGETS -> validateMainTabShell(
                titleView = titleView,
                contentFrame = contentFrame,
                navShell = navShell,
                navRow = navRow,
                rootInnerHeight = rootInnerHeight,
            )
            else -> false
        }
    }

    private fun validateMainTabShell(
        titleView: TextView,
        contentFrame: View,
        navShell: View,
        navRow: View,
        rootInnerHeight: Int,
    ): Boolean {
        if (titleView.visibility != View.VISIBLE || titleView.height <= 0) return false
        if (navShell.visibility != View.VISIBLE) return false
        val titleHeight = titleView.height
        val contentBudget = (rootInnerHeight - titleHeight - navShell.height).coerceAtLeast(1)
        if (contentFrame.height < (contentBudget * 0.60f).toInt()) return false
        if (navShell.height >= (rootInnerHeight * 0.25f).toInt()) return false
        if (navShell.height < navRow.height || navShell.height > navRow.height + dp(navShell, 24)) {
            return false
        }
        val contentLoc = IntArray(2)
        val navLoc = IntArray(2)
        contentFrame.getLocationOnScreen(contentLoc)
        navShell.getLocationOnScreen(navLoc)
        return navLoc[1] >= contentLoc[1] + contentFrame.height - dp(contentFrame, 2)
    }

    private fun validateModalShell(
        titleView: TextView,
        contentFrame: View,
        navShell: View,
        rootInnerHeight: Int,
    ): Boolean {
        if (navShell.visibility != View.GONE) return false
        // Title chrome may be hidden on modal/full-screen targets.
        if (titleView.visibility == View.VISIBLE && titleView.height <= 0) return false
        // Require ~85% useful height with a small measurement tolerance for system insets.
        val minHeight = (rootInnerHeight * 0.85f).toInt() - dp(contentFrame, 8)
        if (contentFrame.height < minHeight.coerceAtLeast(1)) return false
        return true
    }

    private fun logReject(targetScreen: String?, reason: String) {
        Log.d(TAG, "reject target=$targetScreen reason=$reason")
    }

    private fun findContentRoot(bodyContainer: LinearLayout, targetScreen: String?): View? {
        val expected = contentRootForTarget(targetScreen)
        for (i in 0 until bodyContainer.childCount) {
            val child = bodyContainer.getChildAt(i)
            val desc = child.contentDescription?.toString().orEmpty()
            if (expected != null && desc == expected) return child
            if (desc in CONTENT_ROOTS) return child
            if (child is ViewGroup) {
                findContentRootNested(child, expected)?.let { return it }
            }
        }
        return null
    }

    private fun findContentRootNested(root: ViewGroup, expected: String?): View? {
        for (i in 0 until root.childCount) {
            val child = root.getChildAt(i)
            val desc = child.contentDescription?.toString().orEmpty()
            if (expected != null && desc == expected) return child
            if (desc in CONTENT_ROOTS) return child
            if (child is ViewGroup) {
                findContentRootNested(child, expected)?.let { return it }
            }
        }
        return null
    }

    private fun validateSymptoms(
        bodyContainer: LinearLayout,
        titleView: TextView,
        state: SymptomLogState,
    ): Boolean {
        if (state.taxonomy == null) return false
        val title = titleView.text?.toString().orEmpty()
        if (!title.contains("feel", ignoreCase = true) && !title.contains("чувств", ignoreCase = true)) {
            return false
        }
        if (bodyContainer.childCount <= 0) return false
        val required = listOf(
            HiAirGeometryMarkers.SYMPTOMS_RECOVERY_HERO,
            HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID,
            HiAirGeometryMarkers.SYMPTOMS_CHIP_GRID,
            HiAirGeometryMarkers.SYMPTOMS_INTENSITY,
            HiAirGeometryMarkers.SYMPTOMS_ENERGY,
            HiAirGeometryMarkers.SYMPTOMS_INSIGHT,
            HiAirGeometryMarkers.SYMPTOMS_PRIMARY_CTA,
            HiAirGeometryMarkers.SYMPTOMS_TAXONOMY,
        )
        if (!required.all { findMarker(bodyContainer, it) != null }) return false
        val metrics = findMarker(bodyContainer, HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID) ?: return false
        if (countNumericValues(metrics) < 4) return false
        val intensity = findMarker(bodyContainer, HiAirGeometryMarkers.SYMPTOMS_INTENSITY) ?: return false
        if (!containsDigit(intensity, state.severity.coerceIn(1, 5))) return false
        return true
    }

    private fun validateDashboard(
        bodyContainer: LinearLayout,
        titleView: TextView,
        rootShell: RootShellViewModel,
    ): Boolean {
        if (rootShell.dashboardViewModel.state.status != DashboardStatus.SUCCESS) return false
        if (bodyContainer.height <= titleView.height + dp(bodyContainer, 48)) return false
        if (!listOf(
                HiAirGeometryMarkers.DASHBOARD_HERO,
                HiAirGeometryMarkers.DASHBOARD_WEATHER_GRID,
                HiAirGeometryMarkers.DASHBOARD_PRIMARY_CTA,
            ).all { findMarker(bodyContainer, it) != null }
        ) {
            return false
        }
        val hero = findMarker(bodyContainer, HiAirGeometryMarkers.DASHBOARD_HERO) ?: return false
        // Orb score must be a visible numeric value inside the hero.
        return countNumericValues(hero) >= 1
    }

    private fun validatePlanner(
        bodyContainer: LinearLayout,
        titleView: TextView,
        rootShell: RootShellViewModel,
    ): Boolean {
        if (rootShell.plannerViewModel.state.hourly.isEmpty()) return false
        if (bodyContainer.height <= titleView.height + dp(bodyContainer, 48)) return false
        return listOf(
            HiAirGeometryMarkers.PLANNER_SUMMARY_GRID,
            HiAirGeometryMarkers.PLANNER_CHART,
            HiAirGeometryMarkers.PLANNER_FOOTER_CTA,
        ).all { findMarker(bodyContainer, it) != null }
    }

    private fun validateInsights(bodyContainer: LinearLayout): Boolean {
        return listOf(
            HiAirGeometryMarkers.INSIGHTS_SELECTOR,
            HiAirGeometryMarkers.INSIGHTS_PROGRESS,
        ).all { findMarker(bodyContainer, it) != null }
    }

    private fun validateSettings(bodyContainer: LinearLayout): Boolean {
        if (!listOf(
                HiAirGeometryMarkers.SETTINGS_ACCOUNT,
                HiAirGeometryMarkers.SETTINGS_HEALTH,
            ).all { findMarker(bodyContainer, it) != null }
        ) {
            return false
        }
        if (containsRawKey(bodyContainer)) return false
        val texts = collectTexts(bodyContainer)
        // Match CTA labels only — "Health Connect connected" must not count as Connect.
        val hasConnect = texts.any { isConnectCtaLabel(it) }
        val hasDisconnect = texts.any { isDisconnectCtaLabel(it) }
        if (hasConnect && hasDisconnect) return false
        return true
    }

    private fun isConnectCtaLabel(raw: String): Boolean {
        val text = raw.trim().lowercase()
        if (text.contains("disconnect") || text.contains("отключ") || text.contains("health connect")) {
            return false
        }
        return text == "connect" ||
            text == "подключить" ||
            text == "conectar" ||
            text == "connetti" ||
            text == "connecter"
    }

    private fun isDisconnectCtaLabel(raw: String): Boolean {
        val text = raw.trim().lowercase()
        return text == "disconnect" ||
            text.startsWith("disconnect ") ||
            text.contains("отключ") ||
            text == "desconectar" ||
            text == "disconnetti" ||
            text == "déconnecter" ||
            text == "deconnecter"
    }

    private fun validatePaywall(bodyContainer: LinearLayout): Boolean {
        val required = listOf(
            HiAirGeometryMarkers.PAYWALL_CANVAS,
            HiAirGeometryMarkers.PAYWALL_BENEFITS,
            HiAirGeometryMarkers.PAYWALL_PLANS,
            HiAirGeometryMarkers.PAYWALL_PLAN_MONTHLY,
            HiAirGeometryMarkers.PAYWALL_PLAN_YEARLY,
            HiAirGeometryMarkers.PAYWALL_PURCHASE_CTA,
            HiAirGeometryMarkers.PAYWALL_RESTORE,
            HiAirGeometryMarkers.PAYWALL_LEGAL,
            HiAirGeometryMarkers.PAYWALL_TERMS,
            HiAirGeometryMarkers.PAYWALL_PRIVACY,
            HiAirGeometryMarkers.PAYWALL_CLOSE,
        )
        if (!required.all { findMarker(bodyContainer, it) != null }) return false
        if (containsRawKey(bodyContainer)) return false
        val texts = collectTexts(bodyContainer)
        if (texts.any { it.contains("catalog unavailable", ignoreCase = true) }) return false
        if (texts.any { it.contains("каталог недоступ", ignoreCase = true) }) return false
        val priceHits = texts.count { text ->
            text.contains("$4.99") || text.contains("$39.99") ||
                Regex("""\$\d+(\.\d{2})?""").containsMatchIn(text)
        }
        return priceHits >= 2
    }

    private fun validateOnboarding(bodyContainer: LinearLayout, navShell: View?): Boolean {
        if (navShell != null && navShell.visibility == View.VISIBLE) return false
        val required = listOf(
            HiAirGeometryMarkers.ONBOARDING_HERO,
            HiAirGeometryMarkers.ONBOARDING_FEATURES,
            HiAirGeometryMarkers.ONBOARDING_LOCATION,
            HiAirGeometryMarkers.ONBOARDING_PROGRESS,
            HiAirGeometryMarkers.ONBOARDING_PRIMARY_CTA,
            HiAirGeometryMarkers.ONBOARDING_SECONDARY_CTA,
        )
        if (!required.all { findMarker(bodyContainer, it) != null }) return false
        if (containsRawKey(bodyContainer)) return false
        // Reject duplicate long explanatory sentences (same body copy rendered twice).
        val longTexts = collectTexts(bodyContainer)
            .map { it.trim() }
            .filter { it.length >= 40 }
        if (longTexts.size != longTexts.toSet().size) return false
        return true
    }

    private fun validateNavigation(bodyContainer: LinearLayout, navShell: View?): Boolean {
        return navShell != null &&
            navShell.visibility == View.VISIBLE &&
            navShell.contentDescription == HiAirGeometryMarkers.NAV_BAR &&
            findMarker(bodyContainer, HiAirGeometryMarkers.DASHBOARD_HERO) != null
    }

    private fun findMarker(root: View, marker: String): View? {
        if (root.contentDescription == marker) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                findMarker(root.getChildAt(i), marker)?.let { return it }
            }
        }
        return null
    }

    private fun countNumericValues(root: View): Int {
        var count = 0
        if (root is TextView) {
            val text = root.text?.toString().orEmpty()
            if (text.any { it.isDigit() }) count++
        }
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                count += countNumericValues(root.getChildAt(i))
            }
        }
        return count
    }

    private fun containsDigit(root: View, digit: Int): Boolean {
        val needle = digit.toString()
        if (root is TextView && root.text?.toString()?.contains(needle) == true) return true
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                if (containsDigit(root.getChildAt(i), digit)) return true
            }
        }
        return false
    }

    private fun containsRawKey(root: View): Boolean {
        val keyPattern = Regex("""^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$""")
        fun walk(view: View): Boolean {
            if (view is TextView) {
                val text = view.text?.toString().orEmpty().trim()
                if (keyPattern.matches(text) && !text.startsWith("com.")) return true
            }
            val desc = view.contentDescription?.toString().orEmpty().trim()
            if (
                keyPattern.matches(desc) &&
                !desc.startsWith("geometry.") &&
                !desc.startsWith("store.") &&
                !desc.startsWith("screen.") &&
                !desc.startsWith("com.")
            ) {
                return true
            }
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    if (walk(view.getChildAt(i))) return true
                }
            }
            return false
        }
        return walk(root)
    }

    private fun collectTexts(root: View): List<String> {
        val out = mutableListOf<String>()
        fun walk(view: View) {
            if (view is TextView) {
                view.text?.toString()?.takeIf { it.isNotBlank() }?.let { out.add(it) }
            }
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) walk(view.getChildAt(i))
            }
        }
        walk(root)
        return out
    }

    private fun dp(view: View, value: Int): Int {
        return (value * view.resources.displayMetrics.density).toInt()
    }
}
