package com.hiair.ui.navigation

enum class AppPhase {
    ONBOARDING,
    MAIN
}

enum class OnboardingStep {
    WELCOME,
    VALUE,
    PERSONA,
    LOCATION,
    NOTIFICATIONS,
    HEALTH,
    FIRST_RESULT
}

data class RootShellState(
    val phase: AppPhase = AppPhase.ONBOARDING,
    val onboardingStep: OnboardingStep = OnboardingStep.WELCOME,
    val currentScreen: AppScreen = AppScreen.DASHBOARD
)
