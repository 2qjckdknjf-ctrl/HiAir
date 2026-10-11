package com.hiair.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaceGeocodingTest {
    @Test
    fun coordinateKeyRoundsNearbyPointsTogether() {
        val a = PlaceGeocoding.coordinateKey(41.3874, 2.1686)
        val b = PlaceGeocoding.coordinateKey(41.38745, 2.16862)
        assertEquals(a, b)
    }

    @Test
    fun canReuseWithinOneKilometer() {
        assertTrue(PlaceGeocoding.canReuse(41.3874, 2.1686, 41.3900, 2.1700))
    }

    @Test
    fun cannotReuseAcrossCities() {
        assertFalse(PlaceGeocoding.canReuse(41.3874, 2.1686, 41.2800, 1.9760))
    }
}
