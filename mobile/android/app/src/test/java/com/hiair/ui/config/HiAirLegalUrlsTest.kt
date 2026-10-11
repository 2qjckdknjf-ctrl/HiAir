package com.hiair.ui.config

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HiAirLegalUrlsTest {
    @Test
    fun termsAndPrivacyUseProductionUrls() {
        assertEquals("https://hiair.io/terms/", HiAirLegalUrls.TERMS)
        assertEquals("https://hiair.io/privacy/", HiAirLegalUrls.PRIVACY)
        assertEquals("hello@hiair.io", HiAirLegalUrls.SUPPORT_EMAIL)
        assertTrue(HiAirLegalUrls.PLAY_MANAGE_SUBSCRIPTIONS.startsWith("https://play.google.com/"))
    }

    @Test
    fun urlsUseHttpsAndTrailingSlash() {
        for (url in listOf(HiAirLegalUrls.TERMS, HiAirLegalUrls.PRIVACY)) {
            assertTrue(url.startsWith("https://hiair.io/"))
            assertTrue(url.endsWith("/"))
        }
    }
}
