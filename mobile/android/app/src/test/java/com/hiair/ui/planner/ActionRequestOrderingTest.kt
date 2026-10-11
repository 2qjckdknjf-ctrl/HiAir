package com.hiair.ui.planner

import com.hiair.network.ApiClient
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class ActionRequestOrderingTest {
    @Test fun oldResponseCannotReplaceNewDurationRecommendation() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = AtomicInteger()
        val api = object : ApiClient("http://unused.invalid") {
            override fun createActivityPlan(userId: String, accessToken: String?, profileId: String,
                activity: String, durationMinutes: Int?, intensity: String?, earliestStart: String?,
                latestStart: String?, placeId: String?): String {
                val old = calls.incrementAndGet() == 1
                if (old) { entered.countDown(); check(release.await(3, TimeUnit.SECONDS)) }
                val start = if (old) "2026-10-11T08:00:00+02:00" else "2026-10-11T19:00:00+02:00"
                return """{"timezone":"Europe/Madrid","forecastAvailable":true,"windows":[],"recommendedStart":"$start","planningAccess":"basic"}"""
            }
        }
        val model = DailyPlannerViewModel(api)
        val first = Thread { model.refreshActivityPlan("test", "token", "profile", "en") }
        first.start()
        assertTrue(entered.await(2, TimeUnit.SECONDS))
        model.selectDurationMinutes(60)
        model.refreshActivityPlan("test", "token", "profile", "en")
        release.countDown()
        first.join(3000)
        assertEquals("2026-10-11T19:00:00+02:00", model.state.activityRecommendedStartRaw)
        assertEquals(60, model.state.selectedDurationMinutes)
        assertFalse(model.state.activityPlanLoading)
    }
}
