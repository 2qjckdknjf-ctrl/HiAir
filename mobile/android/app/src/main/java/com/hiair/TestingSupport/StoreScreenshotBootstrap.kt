package com.hiair

import android.content.Intent
import com.hiair.ui.navigation.AppScreen
import com.hiair.ui.navigation.RootShellViewModel
object StoreScreenshotBootstrap {
    const val EXTRA_STORE_SHOTS = "HIAIR_STORE_SHOTS"
    const val EXTRA_SCREEN = "HIAIR_SCREEN"
    const val EXTRA_LANGUAGE = "HIAIR_SHOT_LANGUAGE"

    fun apply(
        intent: Intent?,
        rootShell: RootShellViewModel,
        onboardingStore: OnboardingStore,
    ) {
        if (!BuildConfig.DEBUG) return
        val extras = intent?.extras ?: return
        if (extras.getString(EXTRA_STORE_SHOTS) != "1") return

        extras.getString(EXTRA_LANGUAGE)?.takeIf { it.isNotBlank() }?.let { lang ->
            rootShell.settingsViewModel.setPreferredLanguage(lang)
        }

        when (extras.getString(EXTRA_SCREEN)?.lowercase()) {
            "dashboard" -> rootShell.openDashboard()
            "planner" -> rootShell.openPlanner()
            "insights" -> rootShell.openInsights()
            "symptoms" -> rootShell.openSymptoms()
            "settings" -> rootShell.openSettings()
            "paywall" -> {
                rootShell.openSettings()
                rootShell.settingsViewModel.requestShowPaywall()
            }
            "onboarding" -> {
                onboardingStore.resetForStoreScreenshot()
                rootShell.openDashboard()
                rootShell.settingsViewModel.setUserId("store-shot-user")
                rootShell.settingsViewModel.setAccessToken("store-shot-token")
            }
            "navigation" -> rootShell.openDashboard()
            else -> rootShell.openDashboard()
        }
        if (extras.getString(EXTRA_SCREEN)?.lowercase() != "onboarding") {
            StoreScreenshotMockSeeder.apply(rootShell)
        }
    }
}
