package com.hiair.ui.design

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.Locale

class HiAirHumanDateTest {
    @Test
    fun parsesIsoInternetDateTime() {
        assertNotNull(HiAirHumanDate.parseIso("2024-07-19T08:00:00Z"))
    }

    @Test
    fun parsesIsoWithOffset() {
        assertNotNull(HiAirHumanDate.parseIso("2024-07-19T08:00:00+00:00"))
    }

    @Test
    fun displayNeverReturnsRawIso() {
        val iso = "2024-07-19T08:00:00+00:00"
        val displayed = HiAirHumanDate.display(iso, Locale.US)
        assertFalse(displayed.contains("T08:00:00"))
        assertFalse(displayed.contains("+00:00"))
        assertNotEquals(iso, displayed)
    }

    @Test
    fun invalidIsoReturnsUnavailableFallback() {
        assertEquals("—", HiAirHumanDate.display("not-a-date", unavailable = "—"))
        assertNull(HiAirHumanDate.parseIso("not-a-date"))
    }

    @Test
    fun timeRangeUsesEnDash() {
        val start = HiAirHumanDate.parseIso("2024-07-19T08:00:00Z")!!
        val end = HiAirHumanDate.parseIso("2024-07-19T09:00:00Z")!!
        val range = HiAirHumanDate.timeRange(
            start,
            end,
            Locale.UK,
            ZoneOffset.UTC,
        )
        assertTrue(range.contains("–"))
        assertFalse(range.contains("T08"))
    }

    @Test
    fun zoneIdFallsBackWhenIdentifierIsUnknown() {
        assertEquals(ZoneId.systemDefault(), HiAirHumanDate.zoneId(null))
        assertEquals(ZoneId.systemDefault(), HiAirHumanDate.zoneId("not-a-zone"))
        assertEquals(ZoneId.of("Europe/Madrid"), HiAirHumanDate.zoneId("Europe/Madrid"))
    }
}

class HiAirStatusLevelTest {
    @Test
    fun mapsLegacyRiskTokens() {
        assertEquals(HiAirStatusLevel.GOOD, HiAirStatusLevel.fromRiskLevel("low"))
        assertEquals(HiAirStatusLevel.MODERATE, HiAirStatusLevel.fromRiskLevel("moderate"))
        assertEquals(HiAirStatusLevel.BAD, HiAirStatusLevel.fromRiskLevel("high"))
        assertEquals(HiAirStatusLevel.EXCELLENT, HiAirStatusLevel.fromRiskLevel("excellent"))
    }
}
