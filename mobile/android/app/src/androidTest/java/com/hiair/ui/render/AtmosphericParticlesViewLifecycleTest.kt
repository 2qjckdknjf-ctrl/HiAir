package com.hiair.ui.render

import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AtmosphericParticlesViewLifecycleTest {
    @get:Rule
    val activityRule = ActivityScenarioRule(ComponentActivity::class.java)

    @Test
    fun animatorStartsOnAttachAndStopsOnDetach() {
        activityRule.scenario.onActivity { activity ->
            val view = AtmosphericParticlesView(activity)
            assertFalse(view.isTickerRunningForTests())

            val root = FrameLayout(activity)
            activity.setContentView(root)
            root.addView(view)
            assertTrue(view.isTickerRunningForTests())

            root.removeView(view)
            assertFalse(view.isTickerRunningForTests())

            root.addView(view)
            assertTrue(view.isTickerRunningForTests())
        }
    }

    @Test
    fun repeatedAttachCyclesDoNotLeakSecondAnimator() {
        activityRule.scenario.onActivity { activity ->
            val view = AtmosphericParticlesView(activity)
            val root = FrameLayout(activity)
            activity.setContentView(root)
            repeat(3) {
                root.addView(view)
                assertTrue(view.isTickerRunningForTests())
                root.removeView(view)
                assertFalse(view.isTickerRunningForTests())
            }
        }
    }
}
