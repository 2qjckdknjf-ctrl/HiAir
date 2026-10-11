package com.hiair.ui.planner
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ActionTimePreferenceTest {
    @Test fun morningRollsToTomorrowAfterLocalDeadline() {
        val bounds = ActionTimePreference.MORNING.bounds("Europe/Madrid", Instant.parse("2026-10-11T16:00:00Z"))
        assertEquals("2026-10-12T06:00+02:00", bounds.first)
        assertEquals("2026-10-12T11:59:59+02:00", bounds.second)
    }
    @Test fun daylightSavingUsesLocalClock() {
        val bounds = ActionTimePreference.MORNING.bounds("Europe/Madrid", Instant.parse("2026-10-25T00:00:00Z"))
        assertEquals("2026-10-25T06:00+01:00", bounds.first)
        assertEquals("2026-10-25T11:59:59+01:00", bounds.second)
    }
    @Test fun unknownZoneCannotInventPhoneTimezone() {
        assertNull(ActionTimePreference.MORNING.bounds("unknown").first)
        assertNull(ActionTimePreference.ANY.bounds("Europe/Madrid").second)
    }
}
