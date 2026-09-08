package com.hiair.ui.planner

import kotlin.test.Test
import kotlin.test.assertEquals

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
}
