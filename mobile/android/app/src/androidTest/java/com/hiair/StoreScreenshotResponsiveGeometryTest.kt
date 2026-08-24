package com.hiair

import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hiair.ui.accessibility.HiAirScreenMarkers
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirScreenMetrics
import com.hiair.ui.theme.V2Ui
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StoreScreenshotResponsiveGeometryTest {
    @Test
    fun plannerBodyRespectsMaxCanvasWidth() {
        measureBodyWidth("planner") { bodyWidth, maxWidth ->
            assertTrue("planner body=$bodyWidth max=$maxWidth", bodyWidth in 1..maxWidth + 2)
        }
    }

    @Test
    fun symptomsBodyRespectsMaxCanvasWidth() {
        measureBodyWidth("symptoms") { bodyWidth, maxWidth ->
            assertTrue("symptoms body=$bodyWidth max=$maxWidth", bodyWidth in 1..maxWidth + 2)
        }
    }

    @Test
    fun navigationShellRespectsMaxWidth() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = storeShotIntent("navigation")
        ActivityScenario.launch<AppMainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                val horizontalPad = V2Ui.dp(
                    activity,
                    HiAirScreenMetrics.horizontalPaddingDp(activity.resources.configuration.screenWidthDp),
                )
                val navMax = V2Ui.dp(activity, HiAirScreenMetrics.navBarMaxWidthDp)
                val navWidth = activity.navShellForTests().width
                assertTrue("nav width=$navWidth max=$navMax", navWidth in 1..navMax + horizontalPad)
            }
        }
    }

    private fun measureBodyWidth(screen: String, assertFn: (Int, Int) -> Unit) {
        val intent = storeShotIntent(screen)
        ActivityScenario.launch<AppMainActivity>(intent).use { scenario ->
            scenario.onActivity { activity ->
                val horizontalPad = V2Ui.dp(
                    activity,
                    HiAirScreenMetrics.horizontalPaddingDp(activity.resources.configuration.screenWidthDp),
                )
                val maxWidth = HiAirResponsiveLayout.availableContentWidthPx(activity, horizontalPad)
                val bodyWidth = activity.bodyContainerForTests().width
                assertFn(bodyWidth, maxWidth)
            }
        }
    }

    private fun storeShotIntent(screen: String): Intent {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, screen)
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
            putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "geometry-$screen")
        }
    }
}
