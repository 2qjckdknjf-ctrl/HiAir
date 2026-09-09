package com.hiair.ui.planner

import java.time.OffsetDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class DailyPlannerActionSelectionTest {
    @Test
    fun durationAndIntensitySelectionUpdateActionState() {
        val viewModel = DailyPlannerViewModel()

        viewModel.selectDurationMinutes(60)
        viewModel.selectIntensity("high")

        assertEquals(60, viewModel.state.selectedDurationMinutes)
        assertEquals("high", viewModel.state.selectedIntensity)
    }

    @Test
    fun invalidActionSelectionsAreIgnored() {
        val viewModel = DailyPlannerViewModel()
        val initial = viewModel.state

        viewModel.selectDurationMinutes(10)
        viewModel.selectIntensity("extreme")

        assertEquals(initial.selectedDurationMinutes, viewModel.state.selectedDurationMinutes)
        assertEquals(initial.selectedIntensity, viewModel.state.selectedIntensity)
    }

    @Test
    fun actionUiOptionsStayWithinBackendContract() {
        assertEquals(listOf(15, 30, 45, 60, 90, 120), DailyPlannerViewModel.durationOptionsForUi())
        assertEquals(listOf("low", "moderate", "high"), DailyPlannerViewModel.intensityOptionsForUi())
    }

    @Test
    fun tryLaterShiftPreservesOffsetAndAddsThirtyMinutes() {
        val original = OffsetDateTime.parse("2026-09-09T07:00:00+02:00")
        val shiftedRaw = DailyPlannerViewModel.shiftIsoByMinutesForUi(original.toString(), 30)

        assertNotNull(shiftedRaw)
        assertEquals(original.plusMinutes(30), OffsetDateTime.parse(shiftedRaw))
    }

    @Test
    fun invalidRecommendedTimeCannotBeShifted() {
        assertEquals(null, DailyPlannerViewModel.shiftIsoByMinutesForUi("not-a-time", 30))
    }
}
