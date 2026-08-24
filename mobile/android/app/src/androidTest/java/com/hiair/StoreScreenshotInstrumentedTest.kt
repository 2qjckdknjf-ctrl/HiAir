package com.hiair

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StoreScreenshotInstrumentedTest {
    private lateinit var device: UiDevice

    @Before
    fun setUp() {
        device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    }

    @Test
    fun dashboardScreenLaunchesUnderStoreShotBootstrap() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = Intent(context, AppMainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(StoreScreenshotBootstrap.EXTRA_STORE_SHOTS, "1")
            putExtra(StoreScreenshotBootstrap.EXTRA_SCREEN, "dashboard")
            putExtra(StoreScreenshotBootstrap.EXTRA_LANGUAGE, "en")
        }
        context.startActivity(intent)
        device.waitForIdle(5_000)
        assertTrue(device.pressHome())
    }
}
