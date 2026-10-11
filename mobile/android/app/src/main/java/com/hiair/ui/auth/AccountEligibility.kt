package com.hiair.ui.auth

import java.util.Calendar
import java.util.TimeZone

/** Account age gate — 13+ only, matching iOS AccountEligibility. */
object AccountEligibility {
    const val MINIMUM_AGE_YEARS = 13

    fun youngestAllowedBirthDateMillis(nowMillis: Long = System.currentTimeMillis()): Long {
        val calendar = Calendar.getInstance(TimeZone.getDefault())
        calendar.timeInMillis = nowMillis
        calendar.add(Calendar.YEAR, -MINIMUM_AGE_YEARS)
        return calendar.timeInMillis
    }

    fun isEligible(dateOfBirthMillis: Long, nowMillis: Long = System.currentTimeMillis()): Boolean {
        val birth = Calendar.getInstance(TimeZone.getDefault()).apply { timeInMillis = dateOfBirthMillis }
        val now = Calendar.getInstance(TimeZone.getDefault()).apply { timeInMillis = nowMillis }
        var years = now.get(Calendar.YEAR) - birth.get(Calendar.YEAR)
        if (now.get(Calendar.DAY_OF_YEAR) < birth.get(Calendar.DAY_OF_YEAR)) {
            years -= 1
        }
        return years >= MINIMUM_AGE_YEARS
    }
}
