package com.hiair.ui.design

import android.content.Context
import android.view.View
import android.widget.LinearLayout
import com.hiair.ui.theme.V2Ui

object HiAirGridLayout {
    const val MIN_CARD_WIDTH_DP = 148
    const val MIN_CHIP_WIDTH_DP = 108

    fun resolveColumnCountPx(
        availableRowWidthPx: Int,
        requestedColumns: Int,
        gapPx: Int,
        minItemWidthPx: Int,
    ): Int {
        if (availableRowWidthPx <= 0 || requestedColumns <= 1) return 1
        val gap = gapPx.coerceAtLeast(0)
        val minItem = minItemWidthPx.coerceAtLeast(1)
        var columns = requestedColumns.coerceAtLeast(1)
        while (columns > 1) {
            val totalGaps = gap * (columns - 1)
            val perColumn = (availableRowWidthPx - totalGaps) / columns
            if (perColumn >= minItem) break
            columns -= 1
        }
        return columns.coerceAtLeast(1)
    }

    fun resolveColumnCount(
        availableRowWidthPx: Int,
        requestedColumns: Int,
        gapDp: Int,
        minItemWidthDp: Int,
        fontScale: Float,
        densityDpi: Float = 160f,
    ): Int {
        val density = if (densityDpi <= 0f) 160f else densityDpi
        val gapPx = (gapDp * density / 160f).toInt()
        val minItemPx = ((minItemWidthDp * fontScale.coerceAtLeast(1f)) * density / 160f).toInt()
        return resolveColumnCountPx(availableRowWidthPx, requestedColumns, gapPx, minItemPx)
    }

    fun addAdaptiveGridRows(
        host: LinearLayout,
        context: Context,
        requestedColumns: Int,
        views: List<View>,
        gapDp: Int = HiAirSpacing.sm,
        minItemWidthDp: Int = MIN_CARD_WIDTH_DP,
    ) {
        if (views.isEmpty()) return
        val activity = context as android.app.Activity
        val snapshot = HiAirResponsiveLayout.windowSnapshot(activity)
        val gapPx = V2Ui.dp(context, gapDp)
        val minItemPx = V2Ui.dp(context, (minItemWidthDp * snapshot.fontScale.coerceAtLeast(1f)).toInt())
        val columns = resolveColumnCountPx(
            availableRowWidthPx = snapshot.finalContentWidthPx,
            requestedColumns = requestedColumns,
            gapPx = gapPx,
            minItemWidthPx = minItemPx,
        )
        HiAirResponsiveLayout.addGridRows(host, context, columns, views, gapDp)
    }
}
