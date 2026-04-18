package com.hiair.ui.navigation

enum class AppScreen {
    DASHBOARD,
    PLANNER,
    SYMPTOMS,
    SETTINGS
}

data class AppNavigationState(
    val current: AppScreen = AppScreen.DASHBOARD
)

class AppNavigationViewModel {
    var state: AppNavigationState = AppNavigationState()
        private set

    fun navigateTo(screen: AppScreen) {
        state = state.copy(current = screen)
    }
}
