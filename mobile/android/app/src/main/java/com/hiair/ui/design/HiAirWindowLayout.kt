package com.hiair.ui.design

import android.app.Activity
import android.os.Build
import android.view.View
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import kotlin.math.max
import kotlin.math.roundToInt

/** Measured window layout inputs for responsive V4 presentation. All public padding args are dp. */
data class HiAirWindowLayoutSnapshot(
    val rawWindowWidthPx: Int,
    val rawWindowWidthDp: Int,
    val systemInsetLeftPx: Int,
    val systemInsetRightPx: Int,
    val safeAvailableWidthPx: Int,
    val safeAvailableWidthDp: Int,
    val parentHorizontalPaddingPx: Int,
    val innerAvailableWidthPx: Int,
    val innerAvailableWidthDp: Int,
    val contentMaxWidthPx: Int,
    val finalContentWidthPx: Int,
    val gutterLeftPx: Int,
    val gutterRightPx: Int,
    val layoutMode: HiAirLayoutMode,
    val fontScale: Float,
)

object HiAirWindowLayout {
    fun dpToPx(dp: Int, densityDpi: Float): Int {
        val density = normalizedDensity(densityDpi)
        return max(0, (dp * density / 160f).roundToInt())
    }

    fun pxToDp(px: Int, densityDpi: Float): Int {
        val density = normalizedDensity(densityDpi)
        return max(0, ((px * 160f) / density).roundToInt())
    }

    /** Pure resolver for unit tests — padding is dp, converted to px exactly once. */
    fun resolve(
        rawWindowWidthPx: Int,
        densityDpi: Float,
        insetLeftPx: Int,
        insetRightPx: Int,
        parentHorizontalPaddingEachSideDp: Int,
        fontScale: Float = 1f,
    ): HiAirWindowLayoutSnapshot {
        val density = normalizedDensity(densityDpi)
        val rawWindowWidthDp = pxToDp(rawWindowWidthPx, density)
        val insetLeft = insetLeftPx.coerceAtLeast(0)
        val insetRight = insetRightPx.coerceAtLeast(0)
        val safeAvailablePx = (rawWindowWidthPx - insetLeft - insetRight).coerceAtLeast(0)
        val safeAvailableDp = pxToDp(safeAvailablePx, density)
        val parentPadPx = dpToPx(parentHorizontalPaddingEachSideDp.coerceAtLeast(0), density) * 2
        val innerAvailablePx = (safeAvailablePx - parentPadPx).coerceAtLeast(0)
        val innerAvailableDp = pxToDp(innerAvailablePx, density)
        val layoutMode = HiAirScreenMetrics.layoutMode(innerAvailableDp)
        val contentMaxPx = dpToPx(HiAirScreenMetrics.contentMaxWidthDp(innerAvailableDp), density)
        val finalContentPx = minOf(contentMaxPx, innerAvailablePx).coerceAtLeast(0)
        val remaining = (innerAvailablePx - finalContentPx).coerceAtLeast(0)
        val gutterLeft = remaining / 2
        val gutterRight = remaining - gutterLeft
        return HiAirWindowLayoutSnapshot(
            rawWindowWidthPx = rawWindowWidthPx,
            rawWindowWidthDp = rawWindowWidthDp,
            systemInsetLeftPx = insetLeft,
            systemInsetRightPx = insetRight,
            safeAvailableWidthPx = safeAvailablePx,
            safeAvailableWidthDp = safeAvailableDp,
            parentHorizontalPaddingPx = parentPadPx,
            innerAvailableWidthPx = innerAvailablePx,
            innerAvailableWidthDp = innerAvailableDp,
            contentMaxWidthPx = contentMaxPx,
            finalContentWidthPx = finalContentPx,
            gutterLeftPx = gutterLeft,
            gutterRightPx = gutterRight,
            layoutMode = layoutMode,
            fontScale = fontScale,
        )
    }

    fun fromActivity(activity: Activity, parentHorizontalPaddingEachSideDp: Int): HiAirWindowLayoutSnapshot {
        val decor = activity.window.decorView
        val rawWidth = measuredWindowWidthPx(activity, decor)
        val insets = currentSystemInsets(decor)
        return resolve(
            rawWindowWidthPx = rawWidth,
            densityDpi = activity.resources.displayMetrics.densityDpi.toFloat(),
            insetLeftPx = insets.left,
            insetRightPx = insets.right,
            parentHorizontalPaddingEachSideDp = parentHorizontalPaddingEachSideDp,
            fontScale = activity.resources.configuration.fontScale,
        )
    }

    fun snapshotForActivity(activity: Activity): HiAirWindowLayoutSnapshot {
        val provisional = fromActivity(activity, parentHorizontalPaddingEachSideDp = 0)
        val padDp = HiAirScreenMetrics.horizontalPaddingDp(provisional.safeAvailableWidthDp)
        return fromActivity(activity, parentHorizontalPaddingEachSideDp = padDp)
    }

    fun fromView(view: View, parentHorizontalPaddingEachSideDp: Int): HiAirWindowLayoutSnapshot {
        val activity = view.context as? Activity
        if (activity != null) {
            val decorWidth = if (view.width > 0) view.width else measuredWindowWidthPx(activity, view)
            val insets = currentSystemInsets(view)
            return resolve(
                rawWindowWidthPx = decorWidth,
                densityDpi = view.resources.displayMetrics.densityDpi.toFloat(),
                insetLeftPx = insets.left,
                insetRightPx = insets.right,
                parentHorizontalPaddingEachSideDp = parentHorizontalPaddingEachSideDp,
                fontScale = view.resources.configuration.fontScale,
            )
        }
        val width = view.width.takeIf { it > 0 } ?: view.resources.displayMetrics.widthPixels
        return resolve(
            rawWindowWidthPx = width,
            densityDpi = view.resources.displayMetrics.densityDpi.toFloat(),
            insetLeftPx = 0,
            insetRightPx = 0,
            parentHorizontalPaddingEachSideDp = parentHorizontalPaddingEachSideDp,
            fontScale = view.resources.configuration.fontScale,
        )
    }

    private fun normalizedDensity(densityDpi: Float): Float =
        if (densityDpi <= 0f) 160f else densityDpi

    private fun measuredWindowWidthPx(activity: Activity, view: View): Int {
        if (view.width > 0) return view.width
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return activity.windowManager.currentWindowMetrics.bounds.width().coerceAtLeast(0)
        }
        @Suppress("DEPRECATION")
        val displayWidth = activity.windowManager.defaultDisplay?.let { display ->
            val size = android.graphics.Point()
            display.getSize(size)
            size.x
        } ?: 0
        return displayWidth.takeIf { it > 0 } ?: view.resources.displayMetrics.widthPixels
    }

    private fun currentSystemInsets(view: View): Insets {
        val compat = ViewCompat.getRootWindowInsets(view) ?: return Insets.NONE
        return compat.getInsets(
            WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
        )
    }

    fun applyContentWidth(view: View, snapshot: HiAirWindowLayoutSnapshot) {
        val params = view.layoutParams
            ?: android.view.ViewGroup.LayoutParams(
                snapshot.finalContentWidthPx,
                android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        params.width = snapshot.finalContentWidthPx
        view.layoutParams = params
    }
}
