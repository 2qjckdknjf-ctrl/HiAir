package com.hiair.ui.design

object HiAirRiskStyle {
    fun colorForLevel(level: String): Int {
        return when (level.lowercase()) {
            "low" -> HiAirColors.Risk.low
            "moderate", "medium" -> HiAirColors.Risk.moderate
            "high" -> HiAirColors.Risk.high
            "very_high", "very high" -> HiAirColors.Risk.veryHigh
            else -> HiAirColors.Text.secondary
        }
    }
}
