package com.hiair.ui.auth

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccountEligibilityTest {
    @Test
    fun acceptsThirteenYearOldOnBirthday() {
        val now = calendar(2026, Calendar.AUGUST, 26).timeInMillis
        val birth = calendar(2013, Calendar.AUGUST, 26).timeInMillis
        assertTrue(AccountEligibility.isEligible(birth, now))
    }

    @Test
    fun rejectsDayBeforeThirteenthBirthday() {
        val now = calendar(2026, Calendar.AUGUST, 26).timeInMillis
        val birth = calendar(2013, Calendar.AUGUST, 27).timeInMillis
        assertFalse(AccountEligibility.isEligible(birth, now))
    }

    @Test
    fun youngestAllowedBirthDateIsExactlyThirteenYearsAgo() {
        val now = calendar(2026, Calendar.AUGUST, 26).timeInMillis
        val youngest = AccountEligibility.youngestAllowedBirthDateMillis(now)
        assertTrue(AccountEligibility.isEligible(youngest, now))
        assertFalse(AccountEligibility.isEligible(youngest + 24L * 60 * 60 * 1000, now))
    }

    private fun calendar(year: Int, month: Int, day: Int): Calendar {
        return Calendar.getInstance(TimeZone.getDefault()).apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
}
