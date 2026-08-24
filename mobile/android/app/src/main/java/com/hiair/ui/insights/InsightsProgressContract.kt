package com.hiair.ui.insights

/** Progress display invariants for Insights screen captures and UI. */
object InsightsProgressContract {
    fun denominatorForWindow(windowDays: Int): Int = windowDays.coerceAtLeast(1)

    fun clampLoggedDays(loggedDays: Int, denominator: Int): Int {
        val safeDenominator = denominatorForWindow(denominator)
        return loggedDays.coerceIn(0, safeDenominator)
    }

    fun isValid(loggedDays: Int, denominator: Int): Boolean {
        val safeDenominator = denominatorForWindow(denominator)
        return loggedDays in 0..safeDenominator
    }

    fun formatFraction(loggedDays: Int, denominator: Int): String {
        val clamped = clampLoggedDays(loggedDays, denominator)
        return "$clamped/${denominatorForWindow(denominator)}"
    }
}
