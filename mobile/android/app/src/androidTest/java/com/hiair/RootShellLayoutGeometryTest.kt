package com.hiair

import android.content.Intent
import android.content.pm.ActivityInfo
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RootShellLayoutGeometryTest {
    @Test
    fun phoneSymptomsStoreShotRootShellLayoutInvariants() {
        verifySymptomsLayoutInvariants(initialOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED)
    }

    @Test
    fun phoneSymptomsLandscapeRootShellLayoutInvariants() {
        verifySymptomsLayoutInvariants(initialOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
    }

    private fun verifySymptomsLayoutInvariants(initialOrientation: Int) {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("symptoms")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            if (initialOrientation != ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED) {
                scenario.onActivity { it.requestedOrientation = initialOrientation }
            }
            HiAirGeometryTestSupport.waitForRootShellLayout(activity)
            scenario.onActivity {
                HiAirGeometryTestSupport.assertRootShellLayoutInvariants(
                    activity = it,
                    expectScrollableBody = true,
                )
            }
            HiAirGeometryTestSupport.waitForMarker(activity, HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID)
            scenario.onActivity {
                HiAirGeometryTestSupport.assertRootShellLayoutInvariants(
                    activity = it,
                    expectScrollableBody = true,
                )
            }
        }
    }

    @Test
    fun navigationShellHeightMatchesNavRowContent() {
        ActivityScenario.launch<AppMainActivity>(storeShotIntent("symptoms")).use { scenario ->
            lateinit var activity: AppMainActivity
            scenario.onActivity { activity = it }
            val report = HiAirGeometryTestSupport.waitForRootShellLayout(activity)
            scenario.onActivity {
                HiAirGeometryTestSupport.assertRootShellLayoutInvariants(it)
                assertNotNull(it.navRowForTests().contentDescription)
            }
            org.junit.Assert.assertTrue(
                "nav shell should hug nav row: ${report.summary()}",
                report.navShellHeight <= report.navRowHeight + com.hiair.ui.theme.V2Ui.dp(activity, 24),
            )
        }
    }

    private fun storeShotIntent(screen: String): Intent {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, screen)
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
            putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "layout-$screen")
        }
    }
}
