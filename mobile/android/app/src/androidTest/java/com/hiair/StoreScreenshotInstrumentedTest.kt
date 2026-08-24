package com.hiair

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import com.hiair.ui.accessibility.HiAirScreenMarkers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StoreScreenshotInstrumentedTest {
    private lateinit var device: UiDevice

    private val screens = listOf(
        Triple("dashboard", HiAirScreenMarkers.DASHBOARD, HiAirScreenMarkers.NAVIGATION),
        Triple("planner", HiAirScreenMarkers.PLANNER, HiAirScreenMarkers.NAVIGATION),
        Triple("insights", HiAirScreenMarkers.INSIGHTS, HiAirScreenMarkers.NAVIGATION),
        Triple("symptoms", HiAirScreenMarkers.SYMPTOMS, HiAirScreenMarkers.NAVIGATION),
        Triple("settings", HiAirScreenMarkers.SETTINGS, HiAirScreenMarkers.NAVIGATION),
        Triple("paywall", HiAirScreenMarkers.PAYWALL, null),
        Triple("onboarding", HiAirScreenMarkers.ONBOARDING, null),
        Triple("navigation", HiAirScreenMarkers.NAVIGATION, HiAirScreenMarkers.NAVIGATION),
    )

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun allStoreScreenshotScreensReachableWithMarkers() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        for ((screen, rootMarker, navMarker) in screens) {
            device.executeShellCommand("am force-stop ${HiAirScreenMarkers.PACKAGE}")
            val intent = Intent(context, AppMainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
                putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, screen)
                putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
                putExtra(StoreScreenshotBootstrap.EXTRA_CAPTURE_RUN_ID, "instrumented-${screen}")
            }
            context.startActivity(intent)
            assertTrue(
                "HiAir not foreground for $screen",
                device.wait(Until.hasObject(By.pkg(HiAirScreenMarkers.PACKAGE)), 8_000),
            )
            assertNotNull(
                "Missing root marker $rootMarker for $screen",
                device.wait(Until.findObject(By.desc(rootMarker)), 8_000),
            )
            navMarker?.let { nav ->
                assertNotNull(
                    "Missing nav marker $nav for $screen",
                    device.wait(Until.findObject(By.desc(nav)), 5_000),
                )
            }
            val fg = device.executeShellCommand("dumpsys activity activities")
            assertTrue("Launcher foreground after $screen", fg.contains(HiAirScreenMarkers.PACKAGE))
        }
        assertEquals(HiAirScreenMarkers.PACKAGE, device.currentPackageName)
    }
}
