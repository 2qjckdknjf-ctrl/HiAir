package com.hiair

import android.app.Activity
import android.content.Intent
import android.content.pm.ActivityInfo
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.accessibility.HiAirScreenMarkers
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters

@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class StoreScreenshotColdStartSymptomsTest {
    private lateinit var device: UiDevice

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun a_phoneColdStartSymptomsStoreShotAfterPmClear() {
        clearAppDataLikePmClear()
        ActivityScenario.launch<AppMainActivity>(storeShotIntent()).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            waitForHealthyLayout(activity)
            waitForReady(activity, StoreScreenshotReadiness.SYMPTOMS)
            assertSymptomsContentPresent(activity)
            device.swipe(
                device.displayWidth / 2,
                (device.displayHeight * 0.85).toInt(),
                device.displayWidth / 2,
                (device.displayHeight * 0.2).toInt(),
                24,
            )
            HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_TAXONOMY)
        }
    }

    @Test
    fun b_phoneColdStartSymptomsPreservesStateAfterRotation() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent()).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            waitForHealthyLayout(activity)
            waitForReady(activity, StoreScreenshotReadiness.SYMPTOMS)
            assertSymptomsContentPresent(activity)
            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            waitForHealthyLayout(activity)
            waitForReady(activity, StoreScreenshotReadiness.SYMPTOMS)
            assertSymptomsContentPresent(activity)
            scenario.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED }
            waitForHealthyLayout(activity)
            waitForReady(activity, StoreScreenshotReadiness.SYMPTOMS)
            assertSymptomsContentPresent(activity)
        }
    }

    private fun clearAppDataLikePmClear() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        SessionStore(context).clear()
        OnboardingStore(context).setCompleted(false)
        context.getSharedPreferences("hiair", android.content.Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun waitForHealthyLayout(activity: AppMainActivity) {
        val report = HiAirGeometryTestSupport.waitForRootShellLayout(activity, timeoutMs = 12_000L)
        val failure = HiAirGeometryTestSupport.classifyLayoutFailure(report)
        when (failure) {
            HiAirGeometryTestSupport.LayoutFailureMode.NO_BODY_CHILDREN ->
                fail("Renderer did not create body children: ${report.summary()}")
            HiAirGeometryTestSupport.LayoutFailureMode.COLLAPSED_VIEWPORT ->
                fail("Body children exist but viewport collapsed: ${report.summary()}")
            HiAirGeometryTestSupport.LayoutFailureMode.READINESS_CONTRACT,
            HiAirGeometryTestSupport.LayoutFailureMode.OK,
            -> {
                InstrumentationRegistry.getInstrumentation().runOnMainSync {
                    HiAirGeometryTestSupport.assertRootShellLayoutInvariants(
                        activity = activity,
                        expectScrollableBody = true,
                    )
                }
            }
        }
    }

    private fun storeShotIntent(): Intent {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, "symptoms")
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
            putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "cold-start-symptoms")
        }
    }

    private fun waitForReady(activity: AppMainActivity, marker: String) {
        val deadline = System.currentTimeMillis() + 12_000L
        while (System.currentTimeMillis() < deadline) {
            var ready = false
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                ready = HiAirGeometryTestSupport.findByContentDescription(
                    activity.window.decorView,
                    marker,
                ) != null
            }
            if (ready) return
            if (device.hasObject(By.desc(marker))) return
            Thread.sleep(50)
        }
        val report = HiAirGeometryTestSupport.collectLayoutBounds(activity)
        val failure = HiAirGeometryTestSupport.classifyLayoutFailure(report)
        when (failure) {
            HiAirGeometryTestSupport.LayoutFailureMode.NO_BODY_CHILDREN ->
                fail("Missing readiness $marker: renderer did not create children: ${report.summary()}")
            HiAirGeometryTestSupport.LayoutFailureMode.COLLAPSED_VIEWPORT ->
                fail("Missing readiness $marker: viewport collapsed: ${report.summary()}")
            HiAirGeometryTestSupport.LayoutFailureMode.OK,
            HiAirGeometryTestSupport.LayoutFailureMode.READINESS_CONTRACT,
            ->
                fail("Missing readiness $marker: content visible but readiness contract failed: ${report.summary()}")
        }
    }

    private fun assertSymptomsContentPresent(activity: Activity) {
        listOf(
            HiAirGeometryMarkers.SYMPTOMS_RECOVERY_HERO,
            HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID,
            HiAirGeometryMarkers.SYMPTOMS_CHIP_GRID,
            HiAirGeometryMarkers.SYMPTOMS_INTENSITY,
            HiAirGeometryMarkers.SYMPTOMS_ENERGY,
            HiAirGeometryMarkers.SYMPTOMS_INSIGHT,
            HiAirGeometryMarkers.SYMPTOMS_PRIMARY_CTA,
            HiAirGeometryMarkers.SYMPTOMS_TAXONOMY,
        ).forEach { marker ->
            val view = HiAirGeometryTestSupport.waitForMarker(activity, marker)
            assertTrue("marker $marker not laid out", view.width > 0 && view.height > 0)
        }
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            val body = (activity as AppMainActivity).bodyContainerForTests()
            assertTrue(body.childCount > 0)
            val metrics = HiAirGeometryTestSupport.findByContentDescription(
                body,
                HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID,
            )
            assertNotNull(metrics)
            assertTrue(hasNumericText(metrics!!, "72"))
            assertTrue(hasNumericText(metrics, "6,842"))
        }
    }

    private fun hasNumericText(root: android.view.View, needle: String): Boolean {
        if (root is android.widget.TextView && root.text?.toString()?.contains(needle) == true) {
            return true
        }
        if (root is android.view.ViewGroup) {
            for (index in 0 until root.childCount) {
                if (hasNumericText(root.getChildAt(index), needle)) return true
            }
        }
        return false
    }
}
