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

    private fun bundleString(extras: android.os.Bundle, key: String): String? {
        extras.getString(key)?.takeIf { it.isNotBlank() }?.let { return it }
        return extras.getCharSequence(key)?.toString()?.takeIf { it.isNotBlank() }
    }

    private fun bundleFlag(extras: android.os.Bundle, key: String): Boolean {
        bundleString(extras, key)?.let { value ->
            if (value == "1" || value.equals("true", ignoreCase = true)) return true
        }
        return extras.getInt(key, 0) == 1
    }

    fun apply(
        intent: Intent?,
        rootShell: RootShellViewModel,
        onboardingStore: OnboardingStore,
    ) {
        if (!BuildConfig.DEBUG) return
        val extras = intent?.extras ?: return
        if (!bundleFlag(extras, EXTRA_STORE_SHOTS)) return

        val screen = bundleString(extras, EXTRA_SCREEN)?.lowercase()
        val runId = bundleString(extras, EXTRA_CAPTURE_RUN_ID)
        StoreScreenshotMode.activate(screen, runId)

        bundleString(extras, EXTRA_LANGUAGE)?.let { lang ->
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
                    bundleString(extras, EXTRA_LANGUAGE)?.ifBlank { "en" } ?: "en",
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

    /** Re-bootstrap store-shot state when activity receives a new capture intent. */
    fun reapplyIfNeeded(
        intent: Intent?,
        rootShell: RootShellViewModel,
        onboardingStore: OnboardingStore,
    ): Boolean {
        if (!BuildConfig.DEBUG) return false
        val extras = intent?.extras ?: return false
        if (!bundleFlag(extras, EXTRA_STORE_SHOTS)) return false
        apply(intent, rootShell, onboardingStore)
        return true
    }
}
