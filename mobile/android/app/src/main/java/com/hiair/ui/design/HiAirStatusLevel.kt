package com.hiair.ui.design

/**
 * Air-quality / window status levels from the UX audit (Excellent → Bad).
 * Also accepts legacy risk engine tokens (`low`, `moderate`, `high`, `very_high`).
 */
enum class HiAirStatusLevel {
    EXCELLENT,
    GOOD,
    MODERATE,
    BAD,
    ;

    val color: Int
        get() = when (this) {
            EXCELLENT -> HiAirColors.Brand.orbTeal
            GOOD -> HiAirColors.Risk.low
            MODERATE -> HiAirColors.Risk.moderate
            BAD -> HiAirColors.Risk.high
        }

    companion object {
        fun fromRiskLevel(riskLevel: String): HiAirStatusLevel {
            return when (riskLevel.trim().lowercase()) {
                "excellent", "отлично", "excellent_air" -> EXCELLENT
                "good", "low", "хорошо" -> GOOD
                "moderate", "medium", "умеренно", "средний" -> MODERATE
                "bad", "poor", "high", "very_high", "very high", "плохо", "высокий" -> BAD
                else -> MODERATE
            }
        }
    }
}
