package com.hiair.ui.i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Test

class AndroidStoreParityL10nTest {
    @Test
    fun reviewSurfacesAreLocalized() {
        val keys = listOf(
            "settings.restore_purchases",
            "settings.manage_subscription",
            "settings.support",
            "settings.support_email",
            "settings.terms",
            "settings.privacy",
            "paywall.offer_title_monthly",
            "paywall.offer_title_yearly",
            "paywall.length_month",
            "paywall.length_year",
            "paywall.service_period",
            "paywall.manage_subscription",
            "auth.age_note",
            "onboarding.age.title",
            "location.resolving",
            "location.unknown",
            "planner.no_windows",
        )
        for (key in keys) {
            val en = AndroidL10n.t(key, "en")
            val ru = AndroidL10n.t(key, "ru")
            assertNotEquals(key, en)
            assertNotEquals(key, ru)
            assertFalse(en.contains("Barcelona"))
            assertFalse(ru.contains("Барселона"))
        }
        assertEquals("hello@hiair.io", AndroidL10n.t("settings.support_email", "en"))
    }
}
