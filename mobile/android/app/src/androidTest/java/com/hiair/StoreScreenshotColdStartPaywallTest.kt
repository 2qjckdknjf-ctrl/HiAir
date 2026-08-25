package com.hiair

import android.content.Intent
import android.content.pm.ActivityInfo
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StoreScreenshotColdStartPaywallTest {
    private lateinit var device: UiDevice

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun paywallColdStartPortraitAndLandscapeKeepsMockPrices() {
        clearAppData()
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("paywall")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity {
                activity = it
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
            waitForReady(activity, StoreScreenshotReadiness.PAYWALL)
            assertPaywallContent(activity)

            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            waitForReady(activity, StoreScreenshotReadiness.PAYWALL)
            assertPaywallContent(activity)

            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT }
            waitForReady(activity, StoreScreenshotReadiness.PAYWALL)
            assertPaywallContent(activity)
        }
    }

    private fun assertPaywallContent(activity: AppMainActivity) {
        listOf(
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
        ).forEach { marker ->
            assertMarkerInTree(activity, marker)
        }
        var hasMonthly = false
        var hasYearly = false
        var hasCatalogUnavailable = false
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val root = activity.window.decorView
            hasMonthly = textTreeContains(root, "$4.99")
            hasYearly = textTreeContains(root, "$39.99")
            hasCatalogUnavailable = textTreeContains(root, "catalog unavailable")
        }
        assertTrue("missing monthly mock price", hasMonthly)
        assertTrue("missing yearly mock price", hasYearly)
        assertTrue("catalog unavailable visible", !hasCatalogUnavailable)
    }

    private fun textTreeContains(root: android.view.View, needle: String): Boolean {
        if (root is android.widget.TextView) {
            if (root.text?.toString()?.contains(needle) == true) return true
        }
        if (root is android.view.ViewGroup) {
            for (i in 0 until root.childCount) {
                if (textTreeContains(root.getChildAt(i), needle)) return true
            }
        }
        return false
    }

    private fun assertMarkerInTree(activity: AppMainActivity, marker: String) {
        var found = false
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            found = HiAirGeometryTestSupport.findByContentDescription(
                activity.window.decorView,
                marker,
            ) != null
        }
        assertTrue("missing $marker", found)
    }
    private fun clearAppData() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionStore(context).clear()
        OnboardingStore(context).setCompleted(true)
        context.getSharedPreferences("hiair", android.content.Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun storeShotIntent(screen: String): Intent {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, screen)
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
            putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "cold-start-$screen")
        }
    }

    private fun waitForReady(activity: AppMainActivity, marker: String) {
        val deadline = System.currentTimeMillis() + 20_000L
        while (System.currentTimeMillis() < deadline) {
            var ready = false
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                ready = HiAirGeometryTestSupport.findByContentDescription(
                    activity.window.decorView,
                    marker,
                ) != null
            }
            if (ready) return
            Thread.sleep(50)
        }
        val report = HiAirGeometryTestSupport.collectLayoutBounds(activity)
        fail("Missing readiness $marker layout=${report.summary()}")
    }
}
