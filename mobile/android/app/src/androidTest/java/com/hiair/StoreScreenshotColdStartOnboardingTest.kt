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
class StoreScreenshotColdStartOnboardingTest {
    private lateinit var device: UiDevice

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun onboardingColdStartPortraitAndLandscapeStaysOnGuestFlow() {
        clearAppData()
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("onboarding")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity {
                activity = it
                it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
            waitForReady(activity, StoreScreenshotReadiness.ONBOARDING)
            assertOnboardingContent(activity)
            scenario.onActivity {
                assertTrue(it.navShellForTests().visibility == android.view.View.GONE)
            }

            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            waitForReady(activity, StoreScreenshotReadiness.ONBOARDING)
            assertOnboardingContent(activity)
            scenario.onActivity {
                assertTrue(it.navShellForTests().visibility == android.view.View.GONE)
            }

            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT }
            waitForReady(activity, StoreScreenshotReadiness.ONBOARDING)
            assertOnboardingContent(activity)
        }
    }

    private fun assertOnboardingContent(activity: AppMainActivity) {
        listOf(
            HiAirGeometryMarkers.ONBOARDING_HERO,
            HiAirGeometryMarkers.ONBOARDING_FEATURES,
            HiAirGeometryMarkers.ONBOARDING_LOCATION,
            HiAirGeometryMarkers.ONBOARDING_PROGRESS,
            HiAirGeometryMarkers.ONBOARDING_PRIMARY_CTA,
            HiAirGeometryMarkers.ONBOARDING_SECONDARY_CTA,
        ).forEach { marker ->
            var found = false
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                found = HiAirGeometryTestSupport.findByContentDescription(
                    activity.window.decorView,
                    marker,
                ) != null
            }
            assertTrue("missing $marker", found)
        }
        scenarioNavGone(activity)
    }

    private fun scenarioNavGone(activity: AppMainActivity) {
        var navVisible = true
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            navVisible = activity.navShellForTests().visibility == android.view.View.VISIBLE
        }
        assertTrue("authenticated nav visible on guest onboarding", !navVisible)
    }

    private fun clearAppData() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionStore(context).clear()
        OnboardingStore(context).setCompleted(false)
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
