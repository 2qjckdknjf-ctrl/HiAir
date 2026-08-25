package com.hiair.ui.design

import android.graphics.drawable.GradientDrawable

object TimeOfDayBackground {
    fun pageGradient(): GradientDrawable {
        val phase = Tokens.TimeOfDayPhase.current()
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(phase.top, phase.bottom)
        )
    }

    fun surfacePrimary(): Int = HiAirColors.Surface.bg2

    fun surfaceSecondary(): Int = HiAirColors.Surface.bg3

    fun surfaceElevated(): Int = lighten(HiAirColors.Surface.bg3, 0.08f)

    private fun lighten(color: Int, amount: Float): Int {
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(color, hsv)
        hsv[2] = (hsv[2] + amount).coerceAtMost(1f)
        return android.graphics.Color.HSVToColor(android.graphics.Color.alpha(color), hsv)
    }
}
