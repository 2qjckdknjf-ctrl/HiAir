package com.hiair

import android.content.Intent
import com.hiair.ui.render.FirstRunOnboardingRenderer
import com.hiair.ui.navigation.RootShellViewModel

object StoreScreenshotBootstrap {
    const val EXTRA_STORE_SHOTS = "HIAIR_STORE_SHOTS"
    const val EXTRA_SCREEN = "HIAIR_SCREEN"
    const val EXTRA_LANGUAGE = "HIAIR_SHOT_LANGUAGE"
    const val EXTRA_CAPTURE_RUN_ID = "HIAIR_CAPTURE_RUN_ID"
    const val EXTRA_CAPTURE_OUT = "HIAIR_CAPTURE_OUT"

    fun apply(
        intent: Intent?,
        rootShell: RootShellViewModel,
        onboardingStore: OnboardingStore,
    ) {
        if (!BuildConfig.DEBUG) return
        val extras = intent?.extras ?: return
        if (extras.getString(EXTRA_STORE_SHOTS) != "1") return

        val screen = extras.getString(EXTRA_SCREEN)?.lowercase()
        val runId = extras.getString(EXTRA_CAPTURE_RUN_ID)
        StoreScreenshotMode.activate(screen, runId)

        extras.getString(EXTRA_LANGUAGE)?.takeIf { it.isNotBlank() }?.let { lang ->
            rootShell.settingsViewModel.setPreferredLanguage(lang)
        }

        when (screen) {
            "dashboard" -> rootShell.openDashboard()
            "planner" -> rootShell.openPlanner()
            "insights" -> rootShell.openInsights()
            "symptoms" -> rootShell.openSymptoms()
            "settings" -> rootShell.openSettings()
            "paywall" -> {
                onboardingStore.setCompleted(true)
                rootShell.openSettings()
                rootShell.settingsViewModel.requestShowPaywall()
            }
            "onboarding" -> {
                onboardingStore.resetForStoreScreenshot()
                FirstRunOnboardingRenderer.prepareStoreScreenshotWelcome()
                rootShell.settingsViewModel.seedStoreScreenshotOnboarding(
                    extras.getString(EXTRA_LANGUAGE)?.ifBlank { "en" } ?: "en",
                )
                rootShell.openDashboard()
            }
            "navigation" -> {
                onboardingStore.setCompleted(true)
                rootShell.openDashboard()
            }
            else -> rootShell.openDashboard()
        }

        if (screen != "onboarding") {
            onboardingStore.setCompleted(true)
            StoreScreenshotMockSeeder.apply(rootShell)
        }
    }
}
