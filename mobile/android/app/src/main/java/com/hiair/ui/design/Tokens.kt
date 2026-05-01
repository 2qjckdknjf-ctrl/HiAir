package com.hiair.ui.design

import android.graphics.Color
import java.util.Calendar

object Tokens {
    object Text {
        val primary: Int = Color.parseColor("#F0F4FF")
        val secondary: Int = Color.parseColor("#A8B5D1")
        val tertiary: Int = Color.parseColor("#6A7A99")
    }

    object Cta {
        val start: Int = Color.parseColor("#5DD5C4")
        val end: Int = Color.parseColor("#8B7BFF")
    }

    object RiskAccent {
        val low: Int = Color.parseColor("#7DDCB0")
        val moderate: Int = Color.parseColor("#F5B66E")
        val high: Int = Color.parseColor("#F08A8A")
        val veryHigh: Int = Color.parseColor("#C95684")

        fun forLevel(level: String): Int {
            return when (level.lowercase()) {
                "low" -> low
                "moderate", "medium" -> moderate
                "high" -> high
                "very_high", "very high" -> veryHigh
                else -> secondaryFallback
            }
        }

        private val secondaryFallback: Int = Text.secondary
    }

    object RadiusDp {
        const val pill = 999
        const val sm = 8
        const val md = 14
        const val lg = 20
        const val xl = 28
    }

    enum class TimeOfDayPhase(val top: Int, val bottom: Int) {
        Dawn(top = 0xFF1A1530.toInt(), bottom = 0xFF2B2050.toInt()),
        Morning(top = 0xFF1B2845.toInt(), bottom = 0xFF2A4373.toInt()),
        Midday(top = 0xFF1F3260.toInt(), bottom = 0xFF2E4A8A.toInt()),
        Afternoon(top = 0xFF2A2547.toInt(), bottom = 0xFF3D2F5C.toInt()),
        Evening(top = 0xFF1A1A35.toInt(), bottom = 0xFF25193D.toInt()),
        Night(top = 0xFF0E1226.toInt(), bottom = 0xFF181D38.toInt());

        companion object {
            fun current(now: Calendar = Calendar.getInstance()): TimeOfDayPhase {
                return when (val hour = now.get(Calendar.HOUR_OF_DAY)) {
                    in 5..7 -> Dawn
                    in 8..11 -> Morning
                    in 12..15 -> Midday
                    in 16..18 -> Afternoon
                    in 19..21 -> Evening
                    else -> Night
                }
            }
        }
    }
}
