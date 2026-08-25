package com.hiair.ui.design

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HiAirWindowLayoutTest {
    @Test
    fun dpToPxAt160Density() {
        assertEquals(16, HiAirWindowLayout.dpToPx(16, 160f))
    }

    @Test
    fun dpToPxAt320Density() {
        assertEquals(32, HiAirWindowLayout.dpToPx(16, 320f))
    }

    @Test
    fun dpToPxAt420DensityRoundsCorrectly() {
        assertEquals(42, HiAirWindowLayout.dpToPx(16, 420f))
    }

    @Test
    fun paddingConvertedOnceAt320() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1080,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 16,
        )
        assertEquals(64, snapshot.parentHorizontalPaddingPx)
        assertEquals(1016, snapshot.innerAvailableWidthPx)
    }

    @Test
    fun insetsSubtractedOnce() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1080,
            densityDpi = 320f,
            insetLeftPx = 40,
            insetRightPx = 40,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(1000, snapshot.safeAvailableWidthPx)
        assertEquals(1000, snapshot.innerAvailableWidthPx)
    }

    @Test
    fun finalWidthNeverNegativeAndWithinSafeWidth() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 120,
            densityDpi = 320f,
            insetLeftPx = 24,
            insetRightPx = 24,
            parentHorizontalPaddingEachSideDp = 48,
        )
        assertTrue(snapshot.finalContentWidthPx >= 0)
        assertTrue(snapshot.finalContentWidthPx <= snapshot.innerAvailableWidthPx)
    }

    @Test
    fun layoutModeUsesInnerAvailableWidthNotRaw() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1440,
            densityDpi = 320f,
            insetLeftPx = 80,
            insetRightPx = 80,
            parentHorizontalPaddingEachSideDp = 16,
        )
        assertEquals(720, snapshot.rawWindowWidthDp)
        assertEquals(640, snapshot.safeAvailableWidthDp)
        assertEquals(608, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.TABLET, snapshot.layoutMode)
    }

    @Test
    fun safe599IsNotMedium() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1198,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(599, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.STANDARD, snapshot.layoutMode)
    }

    @Test
    fun safe600IsMedium() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1200,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(600, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.TABLET, snapshot.layoutMode)
    }

    @Test
    fun safe839IsMedium() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1678,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(839, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.TABLET, snapshot.layoutMode)
    }

    @Test
    fun safe840IsExpanded() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1680,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(840, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.EXPANDED, snapshot.layoutMode)
    }

    @Test
    fun raw900Safe820IsMedium() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1800,
            densityDpi = 320f,
            insetLeftPx = 80,
            insetRightPx = 80,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(900, snapshot.rawWindowWidthDp)
        assertEquals(820, snapshot.safeAvailableWidthDp)
        assertEquals(HiAirLayoutMode.TABLET, snapshot.layoutMode)
    }

    @Test
    fun splitSafe540IsStandard() {
        val snapshot = HiAirWindowLayout.resolve(
            rawWindowWidthPx = 1080,
            densityDpi = 320f,
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = 0,
        )
        assertEquals(540, snapshot.innerAvailableWidthDp)
        assertEquals(HiAirLayoutMode.STANDARD, snapshot.layoutMode)
    }
}
