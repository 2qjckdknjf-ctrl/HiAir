package com.hiair.ui.accessibility

/** Stable TalkBack / uiautomator root markers for store screenshot semantic validation. */
object HiAirScreenMarkers {
    const val PACKAGE = "com.hiair"

    const val DASHBOARD = "screen.dashboard.root"
    const val PLANNER = "screen.planner.root"
    const val INSIGHTS = "screen.insights.root"
    const val SYMPTOMS = "screen.symptoms.root"
    const val SETTINGS = "screen.settings.root"
    const val PAYWALL = "screen.paywall.root"
    const val ONBOARDING = "screen.onboarding.root"
    const val NAVIGATION = "screen.navigation.root"

    fun forScreen(screen: String?): String? = when (screen?.lowercase()) {
        "dashboard" -> DASHBOARD
        "planner" -> PLANNER
        "insights" -> INSIGHTS
        "symptoms" -> SYMPTOMS
        "settings" -> SETTINGS
        "paywall" -> PAYWALL
        "onboarding" -> ONBOARDING
        "navigation" -> NAVIGATION
        else -> null
    }
}
