package com.hiair.ui.design

import android.graphics.Color
import java.util.Calendar

object Tokens {
    object Text {
        val primary: Int = HiAirColors.Text.primary
        val secondary: Int = HiAirColors.Text.secondary
        val tertiary: Int = HiAirColors.Text.tertiary
    }

    object Cta {
        val start: Int = HiAirColors.Cta.gradientStart
        val mid: Int = HiAirColors.Cta.gradientMid
        val end: Int = HiAirColors.Cta.gradientEnd
        val textOnGradient: Int = HiAirColors.Cta.labelOnGradient
    }

    object Surface {
        val chip: Int = Color.parseColor("#1C355A")
        val chipStroke: Int = Color.parseColor("#325888")
        val tile: Int = Color.parseColor("#20385D")
        val tileStroke: Int = Color.parseColor("#355987")
        val tileSelected: Int = Color.parseColor("#2B5A8A")
        val tileSelectedStroke: Int = Color.parseColor("#67C6FF")
        val progressTrack: Int = Color.parseColor("#2A4A79")
        val weatherBar: Int = Color.parseColor("#5378C8")
        val riskBadgeFillModerate: Int = Color.parseColor("#3A2F17")
        val riskBadgeStrokeModerate: Int = Color.parseColor("#6A5830")
    }

    object Feedback {
        val info: Int = HiAirColors.Feedback.info
        val errorSoft: Int = HiAirColors.Feedback.errorSoft
        val strokeSoft: Int = Color.parseColor("#40FFFFFF")
    }

    object RiskAccent {
        val low: Int = HiAirColors.Risk.low
        val moderate: Int = HiAirColors.Risk.moderate
        val high: Int = HiAirColors.Risk.high
        val veryHigh: Int = HiAirColors.Risk.veryHigh

        fun forLevel(level: String): Int = HiAirRiskStyle.colorForLevel(level)
    }

    object Spacing {
        const val xxs = HiAirSpacing.xxs
        const val xs = HiAirSpacing.xs
        const val sm = HiAirSpacing.sm
        const val md = HiAirSpacing.md
        const val lg = HiAirSpacing.lg
        const val xl = HiAirSpacing.xl
    }

    object RadiusDp {
        const val pill = HiAirRadius.pill
        const val sm = HiAirRadius.sm
        const val md = HiAirRadius.md
        const val lg = HiAirRadius.lg
        const val xl = HiAirRadius.xl
    }

    enum class TimeOfDayPhase(val top: Int, val bottom: Int) {
        Dawn(top = 0xFF050B16.toInt(), bottom = 0xFF16102C.toInt()),
        Morning(top = 0xFF050B16.toInt(), bottom = 0xFF0B1730.toInt()),
        Midday(top = 0xFF081221.toInt(), bottom = 0xFF10244A.toInt()),
        Afternoon(top = 0xFF050B16.toInt(), bottom = 0xFF14142E.toInt()),
        Evening(top = 0xFF050B16.toInt(), bottom = 0xFF120E28.toInt()),
        Night(top = 0xFF050B16.toInt(), bottom = 0xFF081221.toInt());

        companion object {
            fun current(now: Calendar = Calendar.getInstance()): TimeOfDayPhase {
                return when (now.get(Calendar.HOUR_OF_DAY)) {
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
