package com.hiair.ui.navigation

import com.hiair.ui.DashboardViewModel
import com.hiair.ui.planner.DailyPlannerViewModel
import com.hiair.ui.settings.SettingsViewModel
import com.hiair.ui.symptoms.SymptomLogViewModel

data class RootShellState(
    val currentScreen: AppScreen = AppScreen.DASHBOARD
)

class RootShellViewModel(
    val dashboardViewModel: DashboardViewModel = DashboardViewModel(),
    val plannerViewModel: DailyPlannerViewModel = DailyPlannerViewModel(),
    val symptomLogViewModel: SymptomLogViewModel = SymptomLogViewModel(),
    val settingsViewModel: SettingsViewModel = SettingsViewModel()
) {
    var state: RootShellState = RootShellState()
        private set

    fun isAuthenticated(): Boolean {
        val settings = settingsViewModel.state
        return settings.userId.isNotBlank() && settings.accessToken.isNotBlank()
    }

    fun openDashboard() {
        state = state.copy(currentScreen = if (isAuthenticated()) AppScreen.DASHBOARD else AppScreen.SETTINGS)
    }

    fun openPlanner() {
        state = state.copy(currentScreen = if (isAuthenticated()) AppScreen.PLANNER else AppScreen.SETTINGS)
    }

    fun openSymptoms() {
        state = state.copy(currentScreen = if (isAuthenticated()) AppScreen.SYMPTOMS else AppScreen.SETTINGS)
    }

    fun openSettings() {
        state = state.copy(currentScreen = AppScreen.SETTINGS)
    }
}
