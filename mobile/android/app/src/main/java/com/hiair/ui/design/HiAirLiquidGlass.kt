package com.hiair.ui.design

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.View
import com.hiair.ui.theme.V2Ui

/** Liquid Glass navigation-layer material (API 31+ blur; tinted fallback below). */
object HiAirLiquidGlass {
    enum class Variant { REGULAR, CLEAR, IDENTITY }

    fun concentricRadius(outerDp: Int, paddingDp: Int): Int = (outerDp - paddingDp).coerceAtLeast(HiAirRadius.sm)

    fun navigationBackground(context: Context): GradientDrawable =
        glassDrawable(context, HiAirRadius.xl, Variant.REGULAR)

    fun cardBackground(context: Context, variant: Variant = Variant.REGULAR): GradientDrawable =
        glassDrawable(context, HiAirRadius.lg, variant)

    fun inputBackground(context: Context): GradientDrawable =
        glassDrawable(context, HiAirRadius.sm + 4, Variant.CLEAR)

    fun glassDrawable(context: Context, cornerDp: Int, variant: Variant): GradientDrawable {
        val radius = V2Ui.dp(context, cornerDp).toFloat()
        val fillAlpha = when (variant) {
            Variant.IDENTITY -> 0xF0
            Variant.REGULAR -> 0x99
            Variant.CLEAR -> 0x66
        }
        val tintAlpha = when (variant) {
            Variant.IDENTITY -> 0x00
            Variant.REGULAR -> 0x24
            Variant.CLEAR -> 0x14
        }
        val base = TimeOfDayBackground.surfacePrimary()
        val tinted = blendAlpha(base, tintAlpha)
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(withAlpha(tinted, fillAlpha))
            setStroke(V2Ui.dp(context, 1), 0x5521D7FF)
        }
    }

    fun applyNavigationBlur(view: View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            view.setRenderEffect(
                android.graphics.RenderEffect.createBlurEffect(
                    22f,
                    22f,
                    android.graphics.Shader.TileMode.CLAMP,
                ),
            )
        }
    }

    /**
     * Floating nav shell: blur applies only to the glass background layer;
     * tab icons and labels stay sharp on top.
     */
    fun wrapNavigationContent(
        context: Context,
        navBackground: android.graphics.drawable.Drawable,
        content: android.view.View,
    ): ContentMeasuredGlassFrameLayout {
        val shell = ContentMeasuredGlassFrameLayout(context)
        val blurLayer = android.view.View(context).apply {
            background = navBackground
            importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            isClickable = false
            isFocusable = false
        }
        applyNavigationBlur(blurLayer)
        content.layoutParams = android.widget.FrameLayout.LayoutParams(
            android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
            android.widget.FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        shell.setGlassLayers(blurLayer, content)
        return shell
    }

    fun applySpringPress(view: View) {
        view.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN ->
                v.animate().scaleX(0.978f).scaleY(0.978f).setDuration(130).start()
                android.view.MotionEvent.ACTION_UP,
                android.view.MotionEvent.ACTION_CANCEL ->
                    v.animate().scaleX(1f).scaleY(1f).setDuration(180).start()
            }
            false
        }
    }

    private fun blendAlpha(color: Int, overlayAlpha: Int): Int {
        if (overlayAlpha == 0) return color
        val r = ((color shr 16) and 0xFF)
        val g = ((color shr 8) and 0xFF)
        val b = (color and 0xFF)
        val mix = overlayAlpha / 255f
        val nr = (r + (255 - r) * mix).toInt().coerceIn(0, 255)
        val ng = (g + (255 - g) * mix).toInt().coerceIn(0, 255)
        val nb = (b + (255 - b) * mix).toInt().coerceIn(0, 255)
        return (0xFF shl 24) or (nr shl 16) or (ng shl 8) or nb
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }
}
