package com.hiair.ui.design

import android.graphics.Color

object HiAirColors {
    object Surface {
        val bg0: Int = Color.parseColor("#050B16")
        val bg1: Int = Color.parseColor("#081221")
        val bg2: Int = Color.parseColor("#0B1730")
        val bg3: Int = Color.parseColor("#101B37")
    }

    object Text {
        val primary: Int = Color.parseColor("#FFFFFF")
        val secondary: Int = Color.parseColor("#E4ECF8")
        val tertiary: Int = Color.parseColor("#C5D4EC")
    }

    object Cta {
        val gradientStart: Int = Color.parseColor("#1AE8FF")
        val gradientMid: Int = Color.parseColor("#4D8CFF")
        val gradientEnd: Int = Color.parseColor("#A06AFF")
        val labelOnGradient: Int = Color.parseColor("#FFFFFF")
    }

    object Risk {
        val low: Int = Color.parseColor("#35E6A2")
        val moderate: Int = Color.parseColor("#FFD447")
        val high: Int = Color.parseColor("#FF8A3D")
        val veryHigh: Int = Color.parseColor("#FF4D68")
    }

    object Feedback {
        val info: Int = Color.parseColor("#1AE8FF")
        val errorSoft: Int = Color.parseColor("#FF4D68")
    }

    object Overlay {
        const val subtleAlpha = 0x1F
        const val mediumAlpha = 0x2E
        const val strongAlpha = 0x42
        const val borderSoftAlpha = 0x4D
    }

    object Spectrum {
        val cyan: Int = Color.parseColor("#1AE8FF")
        val electricBlue: Int = Color.parseColor("#4D8CFF")
        val violet: Int = Color.parseColor("#A06AFF")
        val magenta: Int = Color.parseColor("#E05CFF")
    }

    object Brand {
        val orbCyan: Int = Color.parseColor("#1AE8FF")
        val orbTeal: Int = Color.parseColor("#35E6A2")
        val orbViolet: Int = Color.parseColor("#A06AFF")
        val orbMagenta: Int = Color.parseColor("#E05CFF")
        val nightTop: Int = Color.parseColor("#050B16")
        val nightBottom: Int = Color.parseColor("#0B1730")
    }
}
