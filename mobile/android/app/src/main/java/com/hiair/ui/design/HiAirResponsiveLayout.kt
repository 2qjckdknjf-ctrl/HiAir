package com.hiair.ui.design

import android.content.Context
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.theme.V2Ui

object HiAirResponsiveLayout {
    fun screenWidthDp(context: Context): Int = context.resources.configuration.screenWidthDp

    fun layoutMode(context: Context): HiAirLayoutMode =
        HiAirScreenMetrics.layoutMode(screenWidthDp(context))

    fun availableContentWidthPx(context: Context, parentHorizontalPaddingPx: Int = 0): Int {
        val widthDp = screenWidthDp(context)
        val maxPx = V2Ui.dp(context, HiAirScreenMetrics.contentMaxWidthDp(widthDp))
        val insetPx = parentHorizontalPaddingPx.coerceAtLeast(0) * 2
        val screenPx = (context.resources.displayMetrics.widthPixels - insetPx).coerceAtLeast(0)
        return minOf(maxPx, screenPx)
    }

    fun applyContentWidth(view: View, context: Context, parentHorizontalPaddingPx: Int = 0) {
        val targetPx = availableContentWidthPx(context, parentHorizontalPaddingPx)
        val params = view.layoutParams
            ?: android.view.ViewGroup.LayoutParams(targetPx, android.view.ViewGroup.LayoutParams.WRAP_CONTENT)
        params.width = targetPx
        view.layoutParams = params
    }

    fun sectionSpacingPx(context: Context): Int {
        val mode = layoutMode(context)
        return V2Ui.dp(context, HiAirResponsiveSpacing.cardSpacing(mode))
    }

    fun constrainedButtonLayoutParams(context: Context): LinearLayout.LayoutParams {
        val widthDp = screenWidthDp(context)
        val horizontalPad = V2Ui.dp(context, HiAirScreenMetrics.horizontalPaddingDp(widthDp)) * 2
        val maxWidth = minOf(
            V2Ui.dp(context, HiAirScreenMetrics.ctaMaxWidthDp),
            availableContentWidthPx(context, horizontalPad / 2),
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
        val maxWidth = minOf(
            V2Ui.dp(context, HiAirScreenMetrics.readingColumnMaxDp),
            availableContentWidthPx(context),
        )
        return LinearLayout.LayoutParams(maxWidth, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    fun gridColumns(context: Context, maxColumns: Int = 4): Int =
        HiAirScreenMetrics.gridColumnCount(screenWidthDp(context), maxColumns)

    fun addGridRows(
        host: LinearLayout,
        context: Context,
        columnCount: Int,
        views: List<View>,
        gapDp: Int = HiAirSpacing.sm,
    ) {
        if (views.isEmpty()) return
        val columns = columnCount.coerceAtLeast(1)
        views.chunked(columns).forEach { rowViews ->
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
            val pad = columns - rowViews.size
            repeat(pad) {
                row.addView(
                    View(context),
                    LinearLayout.LayoutParams(0, 0, 1f),
                )
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
