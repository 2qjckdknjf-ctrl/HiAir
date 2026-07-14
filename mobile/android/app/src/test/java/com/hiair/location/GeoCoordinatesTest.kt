package com.hiair.location

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GeoCoordinatesTest {
    @Test
    fun acceptsRealCoordinates() {
        assertTrue(GeoCoordinates.isValid(48.85, 2.35))
    }

    @Test
    fun rejectsNullIsland() {
        assertFalse(GeoCoordinates.isValid(0.0, 0.0))
    }

    @Test
    fun rejectsOutOfRange() {
        assertFalse(GeoCoordinates.isValid(91.0, 2.0))
        assertFalse(GeoCoordinates.isValid(41.0, 181.0))
    }
}
