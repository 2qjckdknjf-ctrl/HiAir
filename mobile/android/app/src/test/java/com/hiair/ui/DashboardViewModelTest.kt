package com.hiair.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class DashboardViewModelTest {
    @Test
    fun `score mapping matches backend risk levels`() {
        assertEquals(20, DashboardViewModel.scoreForLevel("low"))
        assertEquals(45, DashboardViewModel.scoreForLevel("moderate"))
        assertEquals(45, DashboardViewModel.scoreForLevel("medium"))
        assertEquals(70, DashboardViewModel.scoreForLevel("high"))
        assertEquals(90, DashboardViewModel.scoreForLevel("very_high"))
    }

    @Test
    fun `unknown level falls back to moderate score`() {
        assertEquals(45, DashboardViewModel.scoreForLevel(""))
        assertEquals(45, DashboardViewModel.scoreForLevel("garbage"))
    }

    @Test
    fun `missing credentials produce empty state without network`() {
        val viewModel = DashboardViewModel()
        viewModel.load(userId = "", accessToken = null, profileId = null)
        assertEquals(DashboardStatus.EMPTY, viewModel.state.status)
    }

    @Test
    fun `missing profile produces empty state without network`() {
        val viewModel = DashboardViewModel()
        viewModel.load(userId = "user-1", accessToken = "token", profileId = "")
        assertEquals(DashboardStatus.EMPTY, viewModel.state.status)
    }

    @Test
    fun `reset returns the screen to initial`() {
        val viewModel = DashboardViewModel()
        viewModel.markLoading()
        assertEquals(DashboardStatus.LOADING, viewModel.state.status)
        viewModel.reset()
        assertEquals(DashboardStatus.INITIAL, viewModel.state.status)
    }
}
