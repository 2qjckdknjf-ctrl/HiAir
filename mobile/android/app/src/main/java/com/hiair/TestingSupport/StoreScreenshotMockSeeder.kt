package com.hiair

import com.hiair.ui.navigation.RootShellViewModel
import com.hiair.ui.symptoms.SymptomCategory
import com.hiair.ui.symptoms.SymptomItem
import com.hiair.ui.symptoms.SymptomTaxonomy

/** DEBUG-only deterministic demo payloads for store screenshot captures. */
object StoreScreenshotMockSeeder {
    fun apply(rootShell: RootShellViewModel) {
        if (!BuildConfig.DEBUG) return
        val lang = rootShell.settingsViewModel.state.preferredLanguage.ifBlank { "en" }
        rootShell.settingsViewModel.seedStoreScreenshotSession(lang)
        rootShell.dashboardViewModel.seedStoreScreenshotDemo(lang)
        rootShell.plannerViewModel.seedStoreScreenshotDemo(lang)
        rootShell.symptomLogViewModel.seedStoreScreenshotDemo(lang)
    }

    fun demoTaxonomy(lang: String): SymptomTaxonomy {
        val ru = lang.startsWith("ru")
        val respiratory = SymptomCategory(
            id = "respiratory",
            label = if (ru) "Дыхание" else "Respiratory",
            symptoms = listOf(
                SymptomItem("cough", if (ru) "Кашель" else "Cough", redFlag = false),
                SymptomItem("shortness_of_breath", if (ru) "Одышка" else "Shortness of breath", redFlag = true),
            ),
        )
        val general = SymptomCategory(
            id = "general",
            label = if (ru) "Общие" else "General",
            symptoms = listOf(
                SymptomItem("headache", if (ru) "Головная боль" else "Headache", redFlag = false),
                SymptomItem("fatigue", if (ru) "Усталость" else "Fatigue", redFlag = false),
            ),
        )
        return SymptomTaxonomy(
            safetyNotice = if (ru) "При острой одышке обратитесь к врачу." else "Seek care for acute breathing difficulty.",
            categories = listOf(respiratory, general),
            count = 4,
        )
    }
}
