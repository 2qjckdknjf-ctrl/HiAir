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

    fun openDashboard() {
        state = state.copy(currentScreen = AppScreen.DASHBOARD)
    }

    fun openPlanner() {
        state = state.copy(currentScreen = AppScreen.PLANNER)
    }

    fun openSymptoms() {
        state = state.copy(currentScreen = AppScreen.SYMPTOMS)
    }

    fun openInsights() {
        state = state.copy(currentScreen = AppScreen.INSIGHTS)
    }

    fun openSettings() {
        state = state.copy(currentScreen = AppScreen.SETTINGS)
    }
}
