package com.hiair

import android.content.Intent
import android.content.pm.ActivityInfo
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.accessibility.HiAirScreenMarkers
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirScreenMetrics
import com.hiair.ui.render.PaywallResponsiveLayout
import com.hiair.ui.theme.V2Ui
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StoreScreenshotResponsiveGeometryTest {
    @Test
    fun dashboardComponentGeometry() = verifyScreen(
        "dashboard",
        listOf(
            HiAirGeometryMarkers.DASHBOARD_HERO,
            HiAirGeometryMarkers.DASHBOARD_WEATHER_GRID,
            HiAirGeometryMarkers.DASHBOARD_RECOMMENDATIONS,
            HiAirGeometryMarkers.DASHBOARD_SAFE_WINDOWS,
            HiAirGeometryMarkers.DASHBOARD_PRIMARY_CTA,
        ),
    )

    @Test
    fun plannerComponentGeometry() = verifyScreen(
        "planner",
        listOf(
            HiAirGeometryMarkers.PLANNER_SUMMARY_GRID,
            HiAirGeometryMarkers.PLANNER_CHART,
            HiAirGeometryMarkers.PLANNER_DAYPART_GRID,
            HiAirGeometryMarkers.PLANNER_UTILITY_ROW,
            HiAirGeometryMarkers.PLANNER_FOOTER_CTA,
        ),
    )

    @Test
    fun insightsComponentGeometry() = verifyScreen(
        "insights",
        listOf(
            HiAirGeometryMarkers.INSIGHTS_SELECTOR,
            HiAirGeometryMarkers.INSIGHTS_PROGRESS,
            HiAirGeometryMarkers.INSIGHTS_TRENDS,
        ),
    )

    @Test
    fun symptomsComponentGeometry() = verifyScreen(
        "symptoms",
        listOf(
            HiAirGeometryMarkers.SYMPTOMS_RECOVERY_HERO,
            HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID,
            HiAirGeometryMarkers.SYMPTOMS_CHIP_GRID,
            HiAirGeometryMarkers.SYMPTOMS_INTENSITY,
            HiAirGeometryMarkers.SYMPTOMS_ENERGY,
            HiAirGeometryMarkers.SYMPTOMS_INSIGHT,
            HiAirGeometryMarkers.SYMPTOMS_PRIMARY_CTA,
            HiAirGeometryMarkers.SYMPTOMS_TAXONOMY,
        ),
    )

    @Test
    fun settingsComponentGeometry() = verifyScreen(
        "settings",
        listOf(
            HiAirGeometryMarkers.SETTINGS_ACCOUNT,
            HiAirGeometryMarkers.SETTINGS_HEALTH,
            HiAirGeometryMarkers.SETTINGS_DESTRUCTIVE,
        ),
    )

    @Test
    fun paywallComponentGeometry() = verifyScreen(
        "paywall",
        listOf(
            HiAirGeometryMarkers.PAYWALL_CANVAS,
            HiAirGeometryMarkers.PAYWALL_BENEFITS,
            HiAirGeometryMarkers.PAYWALL_PLANS,
            HiAirGeometryMarkers.PAYWALL_PLAN_YEARLY,
            HiAirGeometryMarkers.PAYWALL_RESTORE,
            HiAirGeometryMarkers.PAYWALL_LEGAL,
        ),
    )

    @Test
    fun onboardingComponentGeometry() = verifyScreen(
        "onboarding",
        listOf(
            HiAirGeometryMarkers.ONBOARDING_HERO,
            HiAirGeometryMarkers.ONBOARDING_FEATURES,
            HiAirGeometryMarkers.ONBOARDING_LOCATION,
            HiAirGeometryMarkers.ONBOARDING_PRIMARY_CTA,
            HiAirGeometryMarkers.ONBOARDING_PROGRESS,
        ),
    )

    @Test
    fun navigationComponentGeometry() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("navigation")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            val body = activity.bodyContainerForTests()
            HiAirGeometryTestSupport.waitForLayout(activity, body)
            val nav = activity.navShellForTests()
            HiAirGeometryTestSupport.waitForRootShellLayout(activity)
            scenario.onActivity { HiAirGeometryTestSupport.assertRootShellLayoutInvariants(it) }
            val snapshot = activity.windowLayoutSnapshotForTests()
            org.junit.Assert.assertEquals(HiAirGeometryMarkers.NAV_BAR, nav.contentDescription)
            val navMax = V2Ui.dp(activity, HiAirScreenMetrics.navBarMaxWidthDp)
            org.junit.Assert.assertTrue("nav width=${nav.width} max=$navMax", nav.width in 1..navMax + 4)
            org.junit.Assert.assertTrue("nav within safe width", nav.width <= snapshot.safeAvailableWidthPx + 4)
        }
    }

    @Test
    fun symptomsPreservesSelectionAfterOrientationChange() {
        var beforeSeverity = -1
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("symptoms")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            HiAirGeometryTestSupport.waitForLayout(activity, activity.bodyContainerForTests())
            scenario.onActivity {
                beforeSeverity = it.rootShellForTests().symptomLogViewModel.state.severity
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_INTENSITY)
            scenario.onActivity {
                assertEquals(beforeSeverity, it.rootShellForTests().symptomLogViewModel.state.severity)
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
    }

    @Test
    fun paywallPreservesSelectedPlanAfterResize() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("paywall")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            scenario.onActivity {
                it.rootShellForTests().settingsViewModel.setPaywallSelectedPlanId(PaywallResponsiveLayout.PLAN_YEARLY)
            }
            HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.PAYWALL_PLAN_YEARLY)
            scenario.onActivity {
                assertEquals(PaywallResponsiveLayout.PLAN_YEARLY, it.rootShellForTests().settingsViewModel.state.paywallSelectedPlanId)
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            }
            HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.PAYWALL_PLANS)
            scenario.onActivity {
                assertEquals(PaywallResponsiveLayout.PLAN_YEARLY, it.rootShellForTests().settingsViewModel.state.paywallSelectedPlanId)
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
    }

    @Test
    fun settingsExpandedTwoColumnGeometry() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("settings")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            val body = activity.bodyContainerForTests()
            HiAirGeometryTestSupport.waitForLayout(activity, body)
            val sections = runCatching {
                HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SETTINGS_SECTIONS)
            }.getOrNull() ?: return@use
            val account = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SETTINGS_ACCOUNT)
            val destructive = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SETTINGS_DESTRUCTIVE)
            val accountLoc = IntArray(2)
            val destructiveLoc = IntArray(2)
            account.getLocationOnScreen(accountLoc)
            destructive.getLocationOnScreen(destructiveLoc)
            assertTrue(
                "settings columns should be horizontal: accountX=${accountLoc[0]} destructiveX=${destructiveLoc[0]}",
                kotlin.math.abs(accountLoc[0] - destructiveLoc[0]) > V2Ui.dp(activity, 48),
            )
            HiAirGeometryTestSupport.assertWithinContentBounds(sections, body, activity.windowLayoutSnapshotForTests())
        }
    }

    @Test
    fun symptomsBottomControlsClearOfNavigation() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("symptoms")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            val body = activity.bodyContainerForTests()
            HiAirGeometryTestSupport.waitForLayout(activity, body)
            HiAirGeometryTestSupport.scrollContentToEnd(activity)
            val energy = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_ENERGY)
            val insight = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_INSIGHT)
            val primary = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_PRIMARY_CTA)
            val nav = activity.navShellForTests()
            HiAirGeometryTestSupport.waitForLayout(activity, nav)
            val navTop = IntArray(2)
            nav.getLocationOnScreen(navTop)
            listOf(energy, insight, primary).forEach { view ->
                val loc = IntArray(2)
                view.getLocationOnScreen(loc)
                val bottom = loc[1] + view.height
                assertTrue(
                    "view bottom=$bottom should be above nav top=${navTop[1]}",
                    bottom <= navTop[1] - V2Ui.dp(activity, 8),
                )
            }
        }
    }

    @Test
    fun dashboardNavClearanceContract() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("dashboard")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            HiAirGeometryTestSupport.waitForLayout(activity, activity.bodyContainerForTests())
            HiAirGeometryTestSupport.assertBodyPaddingMeetsNavContract(activity)
            val hero = HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.DASHBOARD_HERO)
            HiAirGeometryTestSupport.scrollContentToEnd(activity)
            HiAirGeometryTestSupport.assertClearOfNavigation(
                activity,
                HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.DASHBOARD_SAFE_WINDOWS),
            )
            assertTrue(hero.height > 0)
        }
    }

    @Test
    fun plannerEndScrollClearsNavigation() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("planner")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            HiAirGeometryTestSupport.waitForLayout(activity, activity.bodyContainerForTests())
            HiAirGeometryTestSupport.scrollContentToEnd(activity)
            HiAirGeometryTestSupport.assertClearOfNavigation(
                activity,
                HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.PLANNER_FOOTER_CTA),
            )
        }
    }

    private fun verifyScreen(screen: String, markers: List<String>) {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent(screen)).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            val body = activity.bodyContainerForTests()
            HiAirGeometryTestSupport.waitForLayout(activity, body)
            val snapshot = activity.windowLayoutSnapshotForTests()
            val maxWidth = HiAirResponsiveLayout.availableContentWidthPx(activity)
            assertTrue("$screen body=${body.width} max=$maxWidth", body.width in 1..maxWidth + 4)
            markers.forEach { marker ->
                val view = HiAirGeometryTestSupport.waitForMarker(activity, marker)
                HiAirGeometryTestSupport.assertWithinContentBounds(view, body, snapshot)
            }
            val rootMarker = HiAirScreenMarkers.forScreen(screen)
            if (rootMarker != null) {
                scenario.onActivity { assertEquals(rootMarker, it.bodyContainerForTests().contentDescription) }
            }
        }
    }

    private fun storeShotIntent(screen: String): Intent {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        return Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, screen)
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
            putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "geometry-$screen")
        }
    }
}
