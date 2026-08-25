package com.hiair.ui.design

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HiAirGridLayoutTest {
    @Test
    fun reducesColumnsWhenItemsWouldBeTooNarrow() {
        val columns = HiAirGridLayout.resolveColumnCountPx(
            availableRowWidthPx = 520,
            requestedColumns = 4,
            gapPx = 16,
            minItemWidthPx = 148,
        )
        assertEquals(3, columns)
    }

    @Test
    fun expandedClassDoesNotForceFourColumnsWhenWidthInsufficient() {
        val columns = HiAirGridLayout.resolveColumnCountPx(
            availableRowWidthPx = 360,
            requestedColumns = 4,
            gapPx = 12,
            minItemWidthPx = 108,
        )
        assertEquals(3, columns)
    }

    @Test
    fun fontScaleIncreasesMinimumItemWidth() {
        val normal = HiAirGridLayout.resolveColumnCount(
            availableRowWidthPx = 640,
            requestedColumns = 4,
            gapDp = 8,
            minItemWidthDp = 108,
            fontScale = 1f,
            densityDpi = 320f,
        )
        val large = HiAirGridLayout.resolveColumnCount(
            availableRowWidthPx = 640,
            requestedColumns = 4,
            gapDp = 8,
            minItemWidthDp = 108,
            fontScale = 1.3f,
            densityDpi = 320f,
        )
        assertTrue(large <= normal)
    }

    @Test
    fun singleColumnWhenRowTooNarrow() {
        val columns = HiAirGridLayout.resolveColumnCountPx(
            availableRowWidthPx = 120,
            requestedColumns = 3,
            gapPx = 8,
            minItemWidthPx = 108,
        )
        assertEquals(1, columns)
    }
}
