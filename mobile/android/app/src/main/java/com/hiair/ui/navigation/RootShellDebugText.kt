package com.hiair.ui.navigation

fun renderDebugShellText(state: RootShellState): String {
    return when (state.currentScreen) {
        AppScreen.DASHBOARD -> "Dashboard screen active"
        AppScreen.PLANNER -> "Planner screen active"
        AppScreen.SYMPTOMS -> "Symptoms screen active"
        AppScreen.SETTINGS -> "Settings screen active"
    }
}
