package com.hiair.ui.design

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.DrawableRes
import com.hiair.ui.theme.V2Ui

/**
 * Unified Deep Glass V4 surface contract: tint, border, inner highlight, glow, padding.
 * Presentation-only — use for cards, metrics, day-parts, symptom tiles, settings sections.
 */
object HiAirV4Glass {
    enum class Emphasis { DEFAULT, SELECTED, DESTRUCTIVE }

    fun surfaceBackground(context: Context, emphasis: Emphasis = Emphasis.DEFAULT): GradientDrawable {
        val strokeAlpha = when (emphasis) {
            Emphasis.SELECTED -> 0x99
            Emphasis.DESTRUCTIVE -> 0x72
            Emphasis.DEFAULT -> 0x55
        }
        val fillAlpha = when (emphasis) {
            Emphasis.SELECTED -> 0xC8
            Emphasis.DESTRUCTIVE -> 0xB0
            Emphasis.DEFAULT -> 0x99
        }
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(
                withAlpha(TimeOfDayBackground.surfacePrimary(), fillAlpha + 0x08),
                withAlpha(TimeOfDayBackground.surfacePrimary(), fillAlpha - 0x10),
            ),
        ).apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = V2Ui.dp(context, HiAirRadius.lg).toFloat()
            setStroke(
                V2Ui.dp(context, 1),
                withAlpha(HiAirColors.Cta.gradientStart, strokeAlpha),
            )
        }
    }

    fun iconContainer(context: Context, @DrawableRes iconRes: Int, tint: Int? = null): LinearLayout {
        return LinearLayout(context).apply {
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(withAlpha(HiAirColors.Cta.gradientStart, 0x22))
            }
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, 40),
                V2Ui.dp(context, 40),
            )
            addView(
                ImageView(context).apply {
                    setImageResource(iconRes)
                    imageTintList = tint?.let { android.content.res.ColorStateList.valueOf(it) }
                    scaleType = ImageView.ScaleType.CENTER_INSIDE
                    layoutParams = LinearLayout.LayoutParams(
                        V2Ui.dp(context, 22),
                        V2Ui.dp(context, 22),
                    )
                },
            )
        }
    }

    fun featureRow(
        context: Context,
        @DrawableRes iconRes: Int,
        title: String,
        body: String,
        emphasis: Emphasis = Emphasis.DEFAULT,
    ): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
            )
            background = surfaceBackground(context, emphasis)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
            addView(iconContainer(context, iconRes))
            addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        marginStart = V2Ui.dp(context, HiAirSpacing.sm)
                    }
                    addView(
                        TextView(context).apply {
                            text = title
                            textSize = 15f
                            setTypeface(typeface, Typeface.BOLD)
                            setTextColor(HiAirColors.Text.primary)
                        },
                    )
                    addView(
                        TextView(context).apply {
                            text = body
                            textSize = 12f
                            setTextColor(HiAirColors.Text.secondary)
                            layoutParams = LinearLayout.LayoutParams(
                                LinearLayout.LayoutParams.MATCH_PARENT,
                                LinearLayout.LayoutParams.WRAP_CONTENT,
                            ).apply {
                                topMargin = V2Ui.dp(context, 2)
                            }
                        },
                    )
                },
            )
        }
    }

    fun segmentedControl(
        context: Context,
        labels: List<String>,
        selectedIndex: Int,
    ): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(V2Ui.dp(context, 4), V2Ui.dp(context, 4), V2Ui.dp(context, 4), V2Ui.dp(context, 4))
            background = surfaceBackground(context)
            labels.forEachIndexed { index, label ->
                addView(
                    TextView(context).apply {
                        text = label
                        textSize = 14f
                        gravity = Gravity.CENTER
                        minHeight = V2Ui.dp(context, 40)
                        setTextColor(
                            if (index == selectedIndex) HiAirColors.Text.primary else HiAirColors.Text.secondary,
                        )
                        background = if (index == selectedIndex) {
                            surfaceBackground(context, Emphasis.SELECTED)
                        } else {
                            null
                        }
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                            marginEnd = if (index < labels.lastIndex) V2Ui.dp(context, HiAirSpacing.xxs) else 0
                        }
                    },
                )
            }
        }
    }

    fun sectionCard(context: Context, emphasis: Emphasis = Emphasis.DEFAULT): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
            )
            background = surfaceBackground(context, emphasis)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
        }
    }

    private fun withAlpha(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or ((alpha and 0xFF) shl 24)
}
