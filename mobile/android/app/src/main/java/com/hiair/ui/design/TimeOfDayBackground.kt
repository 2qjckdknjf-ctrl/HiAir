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

    fun surfacePrimary(): Int = lighten(Tokens.TimeOfDayPhase.current().top, 0.06f)

    fun surfaceSecondary(): Int = lighten(Tokens.TimeOfDayPhase.current().top, 0.12f)

    fun surfaceElevated(): Int = lighten(Tokens.TimeOfDayPhase.current().top, 0.18f)

    private fun lighten(color: Int, amount: Float): Int {
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(color, hsv)
        hsv[2] = (hsv[2] + amount).coerceAtMost(1f)
        return android.graphics.Color.HSVToColor(android.graphics.Color.alpha(color), hsv)
    }
}
