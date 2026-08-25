package com.hiair.ui.design

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HiAirScreenMetricsTest {
    @Test
    fun compactPhone_usesSingleColumn() {
        assertEquals(HiAirLayoutMode.COMPACT, HiAirScreenMetrics.layoutMode(359))
        assertEquals(1, HiAirScreenMetrics.gridColumnCount(359))
    }

    @Test
    fun tablet_usesTwoColumns() {
        assertEquals(HiAirLayoutMode.TABLET, HiAirScreenMetrics.layoutMode(800))
        assertEquals(2, HiAirScreenMetrics.gridColumnCount(800))
    }

    @Test
    fun expanded_capsContentWidth() {
        assertTrue(HiAirScreenMetrics.contentMaxWidthDp(1280) <= HiAirScreenMetrics.contentCanvasExpandedDp)
        assertEquals(HiAirLayoutMode.EXPANDED, HiAirScreenMetrics.layoutMode(1280))
    }

    @Test
    fun heroOrb_staysWithinV4Range() {
        val orb = HiAirScreenMetrics.heroOrbDp(1280)
        assertTrue(orb in 220..420)
    }
}
