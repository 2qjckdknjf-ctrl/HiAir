package com.hiair.ui.design

import android.content.Context
import android.content.res.ColorStateList
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
        val activity = context as? android.app.Activity ?: return HiAirSpacing.md
        val provisional = HiAirWindowLayout.fromActivity(activity, parentHorizontalPaddingEachSideDp = 0)
        return HiAirScreenMetrics.horizontalPaddingDp(provisional.safeAvailableWidthDp)
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
            background = HiAirLiquidGlass.inputBackground(context)
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

    fun contentCardBackground(context: Context): GradientDrawable {
        return V2Ui.cardBackground(
            context,
            colorHex(TimeOfDayBackground.surfacePrimary()),
            colorHex(withAlpha(HiAirColors.Text.primary, HiAirColors.Overlay.borderSoftAlpha)),
            HiAirRadius.lg,
        )
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
        return HiAirLiquidGlass.cardBackground(context)
    }

    fun glassAccentContainer(context: Context): LinearLayout {
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

    fun liquidGlassNavBackground(context: Context): GradientDrawable {
        return HiAirLiquidGlass.navigationBackground(context)
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
                intArrayOf(
                    HiAirColors.Cta.gradientStart,
                    HiAirColors.Cta.gradientMid,
                    HiAirColors.Cta.gradientEnd,
                ),
            ).apply {
                cornerRadius = V2Ui.dp(context, HiAirRadius.cta).toFloat()
            }
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(context)
        }
    }

    fun secondaryButton(context: Context, label: String): Button {
        return Button(context).apply {
            text = label
            setTextColor(HiAirColors.Text.primary)
            minHeight = V2Ui.dp(context, 48)
            background = HiAirLiquidGlass.glassDrawable(context, HiAirRadius.md, HiAirLiquidGlass.Variant.REGULAR)
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(context).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.xs)
            }
            HiAirLiquidGlass.applySpringPress(this)
        }
    }

    fun riskSpectrumBarView(context: Context, score: Int): HiAirRiskSpectrumBarView {
        return HiAirRiskSpectrumBarView(context).apply {
            bind(score)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, HiAirSpacing.sm)
                bottomMargin = V2Ui.dp(context, HiAirSpacing.xs)
            }
        }
    }

    fun glassMetricTile(
        context: Context,
        title: String,
        value: String,
        subtitle: String,
    ): LinearLayout {
        return cardContainer(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = V2Ui.dp(context, HiAirSpacing.xs)
            }
            addView(
                TextView(context).apply {
                    text = title
                    textSize = 12f
                    setTextColor(HiAirColors.Text.secondary)
                },
            )
            addView(
                TextView(context).apply {
                    text = value
                    textSize = 22f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirColors.Text.primary)
                },
            )
            addView(
                TextView(context).apply {
                    text = subtitle
                    textSize = 12f
                    setTextColor(HiAirColors.Text.secondary)
                },
            )
        }
    }

    fun shouldShowCompactBrandHeader(): Boolean = !com.hiair.StoreScreenshotMode.active

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

    private fun brandDrawableView(
        context: Context,
        drawableRes: Int,
        widthDp: Int,
        heightDp: Int,
        contentDescription: String = "HiAir",
    ): ImageView {
        return ImageView(context).apply {
            setImageResource(drawableRes)
            imageTintList = null
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, widthDp),
                V2Ui.dp(context, heightDp),
            )
            this.contentDescription = contentDescription
        }
    }

    fun brandLogoMarkView(context: Context, sizeDp: Int): ImageView {
        return brandDrawableView(context, R.drawable.hiair_logo_mark, sizeDp, sizeDp)
    }

    fun brandWordmarkView(context: Context, widthDp: Int = 200): ImageView {
        return brandDrawableView(context, R.drawable.hiair_wordmark, widthDp, 48)
    }

    /** Horizontal mono lockup for dark app backgrounds (Settings footer). */
    fun brandMonoFooterView(context: Context): ImageView {
        return brandDrawableView(context, R.drawable.hiair_mono_light, 128, 38).apply {
            layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
                width = LinearLayout.LayoutParams.WRAP_CONTENT
                height = LinearLayout.LayoutParams.WRAP_CONTENT
                topMargin = V2Ui.dp(context, HiAirSpacing.lg)
                gravity = Gravity.CENTER_HORIZONTAL
            }
        }
    }

    fun hidePageTitle(titleView: TextView) {
        titleView.visibility = View.GONE
        titleView.text = ""
    }

    fun screenWordmark(context: Context, suffix: String): LinearLayout {
        val brand = TextView(context).apply {
            text = "HiAir"
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(HiAirColors.Spectrum.cyan)
        }
        val suffixView = TextView(context).apply {
            text = suffix
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(HiAirColors.Text.primary)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                leftMargin = V2Ui.dp(context, 6)
            }
        }
        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(brand)
            addView(suffixView)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
        }
    }

    fun brandHeader(
        context: Context,
        tagline: String = "Breathe better. Live better.",
        showOrb: Boolean = true,
        orbSizeDp: Int = 96,
        compact: Boolean = false,
    ): LinearLayout {
        return if (compact) {
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                if (showOrb) {
                    addView(brandLogoMarkView(context, orbSizeDp.coerceAtMost(48)).apply {
                        layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
                            bottomMargin = 0
                            rightMargin = V2Ui.dp(context, HiAirSpacing.sm)
                        }
                    })
                }
                addView(brandWordmarkView(context, 140).apply {
                    layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
                        width = LinearLayout.LayoutParams.WRAP_CONTENT
                        height = V2Ui.dp(context, 32)
                    }
                })
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    bottomMargin = V2Ui.dp(context, HiAirSpacing.md)
                }
            }
        } else {
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                if (showOrb) {
                    addView(brandOrbView(context, orbSizeDp))
                }
                addView(brandWordmarkView(context, 220).apply {
                    layoutParams = (layoutParams as LinearLayout.LayoutParams).apply {
                        width = LinearLayout.LayoutParams.WRAP_CONTENT
                        height = V2Ui.dp(context, 44)
                        gravity = Gravity.CENTER_HORIZONTAL
                    }
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
    }

    fun riskGaugeView(context: Context, score: Int, statusLabel: String, riskLevel: String): HiAirRiskGaugeView {
        return HiAirRiskGaugeView(context).apply {
            bind(score, statusLabel, riskLevel)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                V2Ui.dp(context, 220),
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
        }
    }

    fun brandOrbView(context: Context, sizeDp: Int): ImageView {
        return ImageView(context).apply {
            setImageResource(R.drawable.hiair_orb)
            imageTintList = null
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

    fun emptyState(
        context: Context,
        title: String,
        message: String,
        actionTitle: String? = null,
        onAction: (() -> Unit)? = null,
    ): LinearLayout {
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
            if (actionTitle != null && onAction != null) {
                addView(
                    primaryButton(context, actionTitle).apply {
                        setOnClickListener { onAction() }
                        val params = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        )
                        params.topMargin = V2Ui.dp(context, HiAirSpacing.md)
                        layoutParams = params
                    },
                )
            }
            setPadding(
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
                V2Ui.dp(context, HiAirSpacing.lg),
            )
        }
    }

    fun errorState(
        context: Context,
        title: String,
        message: String,
        retryTitle: String? = null,
        onRetry: (() -> Unit)? = null,
    ): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
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
            if (retryTitle != null && onRetry != null) {
                addView(
                    primaryButton(context, retryTitle).apply {
                        setOnClickListener { onRetry() }
                        val params = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        )
                        params.topMargin = V2Ui.dp(context, HiAirSpacing.md)
                        layoutParams = params
                    },
                )
            }
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

    class FloatingTabItem(
        val root: LinearLayout,
        val iconWrap: LinearLayout,
        val icon: ImageView,
        val label: TextView,
    )

    fun floatingTabItem(
        context: Context,
        iconRes: Int,
        label: String,
        onTap: () -> Unit,
    ): FloatingTabItem {
        val iconView = ImageView(context).apply {
            setImageResource(iconRes)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, 22),
                V2Ui.dp(context, 22),
            )
        }
        val iconWrap = LinearLayout(context).apply {
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                V2Ui.dp(context, 48),
                V2Ui.dp(context, 32),
            )
            addView(iconView)
        }
        val labelView = TextView(context).apply {
            text = label
            textSize = 10f
            gravity = Gravity.CENTER
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(context, 4)
            }
        }
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            isClickable = true
            isFocusable = true
            minimumHeight = V2Ui.dp(context, 44)
            setPadding(0, V2Ui.dp(context, 4), 0, V2Ui.dp(context, 2))
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            addView(iconWrap)
            addView(labelView)
            setOnClickListener { onTap() }
        }
        val item = FloatingTabItem(root, iconWrap, iconView, labelView)
        applyFloatingTabSelected(context, item, selected = false)
        return item
    }

    fun applyFloatingTabSelected(
        context: Context,
        item: FloatingTabItem,
        selected: Boolean,
    ) {
        val accent = HiAirColors.Cta.gradientStart
        val muted = HiAirColors.Text.tertiary
        val color = if (selected) accent else muted
        item.icon.imageTintList = ColorStateList.valueOf(color)
        item.label.setTextColor(color)
        item.label.typeface = Typeface.create(
            item.label.typeface,
            if (selected) Typeface.BOLD else Typeface.NORMAL,
        )
        item.iconWrap.background = if (selected) {
            GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = V2Ui.dp(context, 12).toFloat()
                setColor(withAlpha(accent, 0x29))
                setStroke(V2Ui.dp(context, 1), withAlpha(accent, 0xBF))
            }
        } else {
            null
        }
    }

    private fun withAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }
}
