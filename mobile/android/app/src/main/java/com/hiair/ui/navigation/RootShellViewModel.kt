package com.hiair.ui.navigation

import com.hiair.ui.DashboardViewModel
import com.hiair.ui.planner.DailyPlannerViewModel
import com.hiair.ui.settings.SettingsViewModel
import com.hiair.ui.symptoms.SymptomLogViewModel

class RootShellViewModel(
    val dashboardViewModel: DashboardViewModel = DashboardViewModel(),
    val plannerViewModel: DailyPlannerViewModel = DailyPlannerViewModel(),
    val symptomLogViewModel: SymptomLogViewModel = SymptomLogViewModel(),
    val settingsViewModel: SettingsViewModel = SettingsViewModel()
) {
    var state: RootShellState = RootShellState()
        private set

    fun startOnboarding() {
        state = state.copy(phase = AppPhase.ONBOARDING, onboardingStep = OnboardingStep.WELCOME)
    }

    fun setOnboardingStep(step: OnboardingStep) {
        state = state.copy(onboardingStep = step)
    }

    fun completeOnboarding() {
        state = state.copy(phase = AppPhase.MAIN, currentScreen = AppScreen.DASHBOARD)
    }

    fun openDashboard() {
        state = state.copy(currentScreen = AppScreen.DASHBOARD)
    }

    fun openPlanner() {
        state = state.copy(currentScreen = AppScreen.PLANNER)
    }

    fun openSymptoms() {
        state = state.copy(currentScreen = AppScreen.SYMPTOMS)
    }

    fun openSettings() {
        state = state.copy(currentScreen = AppScreen.SETTINGS)
    }
}
