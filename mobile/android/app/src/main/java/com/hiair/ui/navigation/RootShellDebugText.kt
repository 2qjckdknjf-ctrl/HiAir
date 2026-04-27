package com.hiair.ui.navigation

import com.hiair.ui.i18n.AndroidL10n

fun renderDebugShellText(state: RootShellState, language: String = "ru"): String {
    return when (state.currentScreen) {
        AppScreen.DASHBOARD -> AndroidL10n.t("debug.dashboard_active", language)
        AppScreen.PLANNER -> AndroidL10n.t("debug.planner_active", language)
        AppScreen.SYMPTOMS -> AndroidL10n.t("debug.symptoms_active", language)
        AppScreen.SETTINGS -> AndroidL10n.t("debug.settings_active", language)
    }
}
