package com.hiair.ui.design

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.hiair.R
import com.hiair.ui.theme.V2Ui

object HiAirComponents {
    fun pageBackground(): GradientDrawable = TimeOfDayBackground.pageGradient()

    fun horizontalPaddingDp(context: Context): Int {
        return HiAirScreenMetrics.horizontalPaddingDp(context.resources.configuration.screenWidthDp)
    }

    fun inputField(context: Context, hint: String): EditText {
        return EditText(context).apply {
            this.hint = hint
            setTextColor(HiAirColors.Text.primary)
            setHintTextColor(HiAirColors.Text.tertiary)
            setPadding(
                V2Ui.dp(context, 12),
                V2Ui.dp(context, 10),
                V2Ui.dp(context, 12),
                V2Ui.dp(context, 10),
            )
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = V2Ui.dp(context, HiAirRadius.sm + 4).toFloat()
                setColor(withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.mediumAlpha))
                setStroke(V2Ui.dp(context, 1), withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.borderSoftAlpha))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.xs)
            }
        }
    }

    fun sectionTitle(context: Context, title: String): TextView {
        return TextView(context).apply {
            text = title
            textSize = 17f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(HiAirColors.Text.primary)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.xs)
            }
        }
    }

    fun tokenSwatchRow(context: Context, label: String, color: Int): LinearLayout {
        val dot = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, 14),
                V2Ui.dp(context, 14),
            ).apply {
                rightMargin = V2Ui.dp(context, HiAirSpacing.xs)
            }
            background = V2Ui.cardBackground(
                context,
                colorHex(color),
                colorHex(Tokens.Feedback.strokeSoft),
                HiAirRadius.pill,
            )
        }
        val text = TextView(context).apply {
            this.text = label
            textSize = 13f
            setTextColor(HiAirColors.Text.secondary)
        }
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(dot)
            addView(text)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.xxs)
            }
        }
    }

    fun navChipBackground(context: Context, selected: Boolean): GradientDrawable {
        return if (selected) {
            V2Ui.cardBackground(
                context,
                colorHex(Tokens.Surface.tileSelected),
                colorHex(Tokens.Surface.tileSelectedStroke),
                HiAirRadius.md,
            )
        } else {
            V2Ui.cardBackground(
                context,
                colorHex(TimeOfDayBackground.surfaceSecondary()),
                colorHex(withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.borderSoftAlpha)),
                HiAirRadius.md,
            )
        }
    }

    fun cardContainer(context: Context): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
                V2Ui.dp(context, HiAirSpacing.md),
            )
            background = glassCardBackground(context)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.topMargin = V2Ui.dp(context, HiAirSpacing.sm)
            layoutParams = params
        }
    }

    fun glassCardBackground(context: Context): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = V2Ui.dp(context, HiAirRadius.lg).toFloat()
            setColor(TimeOfDayBackground.surfacePrimary())
            setStroke(V2Ui.dp(context, 1), withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.borderSoftAlpha))
        }
    }

    fun primaryButton(context: Context, label: String): Button {
        return Button(context).apply {
            text = label
            setTextColor(HiAirColors.Cta.labelOnGradient)
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            minHeight = V2Ui.dp(context, 48)
            background = GradientDrawable(
                GradientDrawable.Orientation.LEFT_RIGHT,
                intArrayOf(HiAirColors.Cta.gradientStart, HiAirColors.Cta.gradientEnd),
            ).apply {
                cornerRadius = V2Ui.dp(context, HiAirRadius.md).toFloat()
            }
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.topMargin = V2Ui.dp(context, HiAirSpacing.sm)
            layoutParams = params
        }
    }

    fun secondaryButton(context: Context, label: String): Button {
        return Button(context).apply {
            text = label
            setTextColor(HiAirColors.Text.primary)
            minHeight = V2Ui.dp(context, 48)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = V2Ui.dp(context, HiAirRadius.md).toFloat()
                setColor(TimeOfDayBackground.surfaceSecondary())
                setStroke(V2Ui.dp(context, 1), withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.borderSoftAlpha))
            }
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.topMargin = V2Ui.dp(context, HiAirSpacing.xs)
            layoutParams = params
        }
    }

    fun sectionHeader(context: Context, title: String): TextView {
        return TextView(context).apply {
            text = title
            textSize = 17f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(HiAirColors.Text.primary)
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.topMargin = V2Ui.dp(context, HiAirSpacing.sm)
            layoutParams = params
        }
    }

    fun riskChip(context: Context, label: String, riskLevel: String): TextView {
        val accent = HiAirRiskStyle.colorForLevel(riskLevel)
        return TextView(context).apply {
            text = label
            textSize = 11f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(accent)
            setPadding(
                V2Ui.dp(context, 10),
                V2Ui.dp(context, 5),
                V2Ui.dp(context, 10),
                V2Ui.dp(context, 5),
            )
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = V2Ui.dp(context, HiAirRadius.pill).toFloat()
                setColor(withAlpha(accent, 0x33))
            }
        }
    }

    fun brandHeader(context: Context, tagline: String = "Breathe better. Live better.", showOrb: Boolean = true, orbSizeDp: Int = 96): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            if (showOrb) {
                addView(brandOrbView(context, orbSizeDp))
            }
            addView(TextView(context).apply {
                text = "HiAir"
                textSize = 30f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(HiAirColors.Text.primary)
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = tagline
                textSize = 13f
                setTextColor(HiAirColors.Cta.gradientStart)
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
                params.topMargin = V2Ui.dp(context, HiAirSpacing.xs)
                layoutParams = params
            })
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            params.bottomMargin = V2Ui.dp(context, HiAirSpacing.md)
            layoutParams = params
        }
    }

    fun brandOrbView(context: Context, sizeDp: Int): ImageView {
        return ImageView(context).apply {
            setImageResource(R.drawable.hiair_orb)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, sizeDp),
                V2Ui.dp(context, sizeDp),
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
            contentDescription = "HiAir"
        }
    }

    fun emptyState(context: Context, title: String, message: String): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(brandHeader(context))
            addView(TextView(context).apply {
                text = title
                textSize = 17f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(HiAirColors.Text.primary)
                gravity = Gravity.CENTER
            })
            addView(TextView(context).apply {
                text = message
                textSize = 15f
                setTextColor(HiAirColors.Text.secondary)
                gravity = Gravity.CENTER
            })
            setPadding(
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
            )
        }
    }

    fun loadingState(context: Context, message: String): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            addView(ProgressBar(context))
            addView(TextView(context).apply {
                text = message
                textSize = 15f
                setTextColor(HiAirColors.Text.secondary)
                gravity = Gravity.CENTER
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
                params.topMargin = V2Ui.dp(context, HiAirSpacing.sm)
                layoutParams = params
            })
            setPadding(
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
            )
        }
    }

    fun orbView(context: Context, sizeDp: Int, @Suppress("UNUSED_PARAMETER") riskLevel: String): View {
        return brandOrbView(context, sizeDp)
    }

    fun chipBackground(context: Context): GradientDrawable {
        return V2Ui.cardBackground(
            context,
            colorHex(Tokens.Surface.chip),
            colorHex(Tokens.Surface.chipStroke),
            HiAirRadius.pill,
        )
    }

    fun tileBackground(context: Context, selected: Boolean = false): GradientDrawable {
        val fill = if (selected) Tokens.Surface.tileSelected else Tokens.Surface.tile
        val stroke = if (selected) Tokens.Surface.tileSelectedStroke else Tokens.Surface.tileStroke
        return V2Ui.cardBackground(context, colorHex(fill), colorHex(stroke), HiAirRadius.sm + 4)
    }

    fun progressTrackBackground(context: Context): GradientDrawable {
        return V2Ui.cardBackground(
            context,
            colorHex(Tokens.Surface.progressTrack),
            colorHex(Tokens.Surface.progressTrack),
            HiAirRadius.sm,
        )
    }

    fun riskAccentHex(level: String): String = colorHex(HiAirRiskStyle.colorForLevel(level))

    fun colorHex(colorInt: Int): String = String.format("#%08X", colorInt)

    private fun withAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }
}
