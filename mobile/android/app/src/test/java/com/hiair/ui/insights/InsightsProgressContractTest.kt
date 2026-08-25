package com.hiair.ui.insights

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InsightsProgressContractTest {
    @Test
    fun sevenDayWindow_clampsOverflow() {
        assertEquals("7/7", InsightsProgressContract.formatFraction(12, 7))
        assertFalse(InsightsProgressContract.isValid(12, 7))
    }

    @Test
    fun thirtyDayWindow_acceptsValidProgress() {
        assertEquals("5/30", InsightsProgressContract.formatFraction(5, 30))
        assertTrue(InsightsProgressContract.isValid(5, 30))
    }

    @Test
    fun zeroProgress_isValid() {
        assertEquals("0/7", InsightsProgressContract.formatFraction(0, 7))
        assertTrue(InsightsProgressContract.isValid(0, 7))
    }

    @Test
    fun completeProgress_isValid() {
        assertEquals("7/7", InsightsProgressContract.formatFraction(7, 7))
        assertTrue(InsightsProgressContract.isValid(7, 7))
    }
}
