package com.hiair.ui.design

import android.graphics.Color

object HiAirColors {
    object Text {
        val primary: Int = Color.parseColor("#F0F4FF")
        val secondary: Int = Color.parseColor("#A8B5D1")
        val tertiary: Int = Color.parseColor("#6A7A99")
    }

    object Cta {
        val gradientStart: Int = Color.parseColor("#5DD5C4")
        val gradientEnd: Int = Color.parseColor("#8B7BFF")
        val labelOnGradient: Int = Color.parseColor("#0D172A")
    }

    object Risk {
        val low: Int = Color.parseColor("#7DDCB0")
        val moderate: Int = Color.parseColor("#F5B66E")
        val high: Int = Color.parseColor("#F08A8A")
        val veryHigh: Int = Color.parseColor("#C95684")
    }

    object Feedback {
        val info: Int = Color.parseColor("#7BCBFF")
        val errorSoft: Int = Color.parseColor("#FF9AA2")
    }

    object Overlay {
        const val subtleAlpha = 0x14
        const val mediumAlpha = 0x1F
        const val strongAlpha = 0x2E
        const val borderSoftAlpha = 0x24
    }

    object Brand {
        val orbCyan: Int = Color.parseColor("#5DD5C4")
        val orbTeal: Int = Color.parseColor("#3ECFB8")
        val orbViolet: Int = Color.parseColor("#8B7BFF")
        val nightTop: Int = Color.parseColor("#0E1226")
        val nightBottom: Int = Color.parseColor("#181D38")
    }
}
