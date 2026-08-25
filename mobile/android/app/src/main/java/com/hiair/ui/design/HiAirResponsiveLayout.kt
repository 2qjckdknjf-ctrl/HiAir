package com.hiair.ui.design

import android.content.Context
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.theme.V2Ui

object HiAirResponsiveLayout {
    fun windowSnapshot(context: Context): HiAirWindowLayoutSnapshot {
        val activity = context as android.app.Activity
        return HiAirWindowLayout.snapshotForActivity(activity)
    }

    fun screenWidthDp(context: Context): Int = windowSnapshot(context).innerAvailableWidthDp

    fun layoutMode(context: Context): HiAirLayoutMode = windowSnapshot(context).layoutMode

    fun availableContentWidthPx(context: Context): Int =
        windowSnapshot(context).finalContentWidthPx

    fun applyContentWidth(view: View, context: Context) {
        HiAirWindowLayout.applyContentWidth(view, windowSnapshot(context))
    }

    fun sectionSpacingPx(context: Context): Int {
        val mode = layoutMode(context)
        return V2Ui.dp(context, HiAirResponsiveSpacing.cardSpacing(mode))
    }

    fun constrainedButtonLayoutParams(context: Context): LinearLayout.LayoutParams {
        val snapshot = windowSnapshot(context)
        val maxWidth = minOf(
            V2Ui.dp(context, HiAirScreenMetrics.ctaMaxWidthDp),
            snapshot.finalContentWidthPx,
        )
        return LinearLayout.LayoutParams(
            maxWidth,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            topMargin = V2Ui.dp(context, HiAirSpacing.sm)
        }
    }

    fun readingColumnLayoutParams(context: Context): LinearLayout.LayoutParams {
        val snapshot = windowSnapshot(context)
        val maxWidth = minOf(
            V2Ui.dp(context, HiAirScreenMetrics.readingColumnMaxDp),
            snapshot.finalContentWidthPx,
        )
        return LinearLayout.LayoutParams(maxWidth, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    fun gridColumns(context: Context, maxColumns: Int = 4): Int {
        val snapshot = windowSnapshot(context)
        val requested = HiAirScreenMetrics.gridColumnCount(snapshot.innerAvailableWidthDp, maxColumns)
        return HiAirGridLayout.resolveColumnCount(
            availableRowWidthPx = snapshot.finalContentWidthPx,
            requestedColumns = requested,
            gapDp = HiAirSpacing.sm,
            minItemWidthDp = HiAirGridLayout.MIN_CARD_WIDTH_DP,
            fontScale = snapshot.fontScale,
            densityDpi = context.resources.displayMetrics.densityDpi.toFloat(),
        )
    }

    fun addGridRows(
        host: LinearLayout,
        context: Context,
        columnCount: Int,
        views: List<View>,
        gapDp: Int = HiAirSpacing.sm,
        padPartialLastRow: Boolean = false,
    ) {
        if (views.isEmpty()) return
        val columns = columnCount.coerceAtLeast(1)
        views.chunked(columns).forEachIndexed { rowIndex, rowViews ->
            val isLastPartial = rowViews.size < columns && rowIndex == views.chunked(columns).lastIndex
            val row = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    topMargin = V2Ui.dp(context, gapDp)
                }
            }
            rowViews.forEachIndexed { index, child ->
                row.addView(
                    child,
                    LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        if (index < rowViews.lastIndex) {
                            marginEnd = V2Ui.dp(context, gapDp)
                        }
                    },
                )
            }
            if (padPartialLastRow && isLastPartial) {
                repeat(columns - rowViews.size) {
                    row.addView(View(context), LinearLayout.LayoutParams(0, 0, 1f))
                }
            }
            host.addView(row)
        }
    }

    fun sectionLabel(context: Context, title: String, subtitle: String? = null): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            addView(
                TextView(context).apply {
                    text = title
                    textSize = 22f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirColors.Text.primary)
                },
            )
            subtitle?.let {
                addView(
                    TextView(context).apply {
                        text = it
                        textSize = 13f
                        setTextColor(HiAirColors.Text.secondary)
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        ).apply {
                            topMargin = V2Ui.dp(context, HiAirSpacing.xs)
                        }
                    },
                )
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
        }
    }
}
