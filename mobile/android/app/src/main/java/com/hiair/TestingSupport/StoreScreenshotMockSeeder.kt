package com.hiair

import com.hiair.ui.navigation.RootShellViewModel

/** DEBUG-only deterministic demo payloads for store screenshot captures. */
object StoreScreenshotMockSeeder {
    fun apply(rootShell: RootShellViewModel) {
        if (!BuildConfig.DEBUG) return
        val lang = rootShell.settingsViewModel.state.preferredLanguage.ifBlank { "en" }
        rootShell.settingsViewModel.setUserId("store-shot-user")
        rootShell.settingsViewModel.setAccessToken("store-shot-token")
        rootShell.settingsViewModel.setRefreshToken("")
        rootShell.settingsViewModel.setEmail("alex@hiair.io")
        rootShell.settingsViewModel.setProfileId("profile-store-shot")
        rootShell.settingsViewModel.setPreferredLanguage(lang)
        rootShell.dashboardViewModel.seedStoreScreenshotDemo(lang)
        rootShell.plannerViewModel.seedStoreScreenshotDemo(lang)
        rootShell.symptomLogViewModel.seedStoreScreenshotDemo()
    }
}
