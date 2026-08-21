package com.hiair.ui.i18n

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppReviewGuidelineCopyTest {
    private val languages = listOf("en", "ru", "es", "it", "fr")

    @Test
    fun permissionPrePromptDoesNotUseAllowOrDeferWording() {
        for (lang in languages) {
            val continueLabel = AndroidL10n.t("onboarding.permissions.allow", lang).lowercase()
            assertFalse(lang, continueLabel.isEmpty())
            assertFalse("$lang allow key: $continueLabel", continueLabel.contains("allow"))
            assertFalse("$lang allow key: $continueLabel", continueLabel.contains("разреш"))

            val later = AndroidL10n.t("onboarding.permissions.later", lang).lowercase()
            assertFalse("$lang later key: $later", later.contains("later"))
            assertFalse("$lang later key: $later", later.contains("позже"))

            val skip = AndroidL10n.t("wearable.consent.skip", lang).lowercase()
            for (word in listOf("allow", "set up later", "skip")) {
                assertFalse("$lang skip key contains $word: $skip", skip.contains(word))
            }
            assertFalse(skip, skip.contains("пропустить"))
            assertFalse(skip, skip.contains("omitir"))
        }
        assertEquals("Continue", AndroidL10n.t("onboarding.permissions.allow", "en"))
        assertEquals("Продолжить", AndroidL10n.t("onboarding.permissions.allow", "ru"))
    }

    @Test
    fun subscriptionSupportAndAgeCopyMatchIos188() {
        for (lang in languages) {
            assertFalse(lang, AndroidL10n.t("settings.manage_subscription", lang).isEmpty())
            assertFalse(lang, AndroidL10n.t("settings.restore_purchases", lang).isEmpty())
            assertTrue(lang, AndroidL10n.t("settings.support_email", lang).contains("hello@hiair.io"))
            assertFalse(lang, AndroidL10n.t("paywall.legal_auto_renew", lang).isEmpty())
            assertFalse(lang, AndroidL10n.t("settings.delete_account_warning", lang).isEmpty())
            val child = AndroidL10n.t("onboarding.for_child", lang).lowercase()
            assertTrue("$lang child persona must state 13+: $child", child.contains("13"))
            val age = AndroidL10n.t("onboarding.date_of_birth.body", lang)
            assertTrue("$lang age disclosure: $age", age.contains("13"))
            assertFalse(lang, AndroidL10n.t("paywall.offer_title_monthly", lang).isEmpty())
            assertFalse(lang, AndroidL10n.t("paywall.length_month", lang).isEmpty())
            assertFalse(lang, AndroidL10n.t("auth.legal", lang).isEmpty())
        }
        assertEquals("Manage subscription", AndroidL10n.t("settings.manage_subscription", "en"))
        assertEquals("HiAir Premium Monthly", AndroidL10n.t("paywall.offer_title_monthly", "en"))
        assertEquals("HiAir Premium Yearly", AndroidL10n.t("paywall.offer_title_yearly", "en"))
        assertTrue(
            AndroidL10n.t("paywall.length_month", "en").lowercase().contains("month"),
        )
        assertEquals("Terms of Use", AndroidL10n.t("paywall.terms", "en"))
        assertEquals("Privacy Policy", AndroidL10n.t("paywall.privacy", "en"))
        assertEquals("Términos de uso", AndroidL10n.t("paywall.terms", "es"))
        assertEquals("Termini di utilizzo", AndroidL10n.t("paywall.terms", "it"))
        assertEquals("Conditions d'utilisation", AndroidL10n.t("paywall.terms", "fr"))
        assertFalse(
            AndroidL10n.t("auth.sign_in_google", "en").isEmpty(),
        )
        assertEquals("auth.sign_in_apple", AndroidL10n.t("auth.sign_in_apple", "en"))
    }
}
