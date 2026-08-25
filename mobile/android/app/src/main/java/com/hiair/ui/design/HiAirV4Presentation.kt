package com.hiair.ui.design

import android.content.Context
import android.content.res.Configuration
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.theme.V2Ui

/** Deep Glass V4 presentation helpers (layout/composition only). */
object HiAirV4Presentation {
    fun isLandscape(context: Context): Boolean =
        context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    fun boundedCanvasMaxDp(context: Context): Int {
        val mode = HiAirResponsiveLayout.layoutMode(context)
        val widthDp = HiAirResponsiveLayout.screenWidthDp(context)
        return when (mode) {
            HiAirLayoutMode.COMPACT, HiAirLayoutMode.STANDARD -> widthDp
            HiAirLayoutMode.TABLET -> minOf(720, widthDp)
            HiAirLayoutMode.EXPANDED -> minOf(840, widthDp)
        }
    }

    fun boundedCanvasLayoutParams(context: Context): LinearLayout.LayoutParams {
        val snapshot = HiAirResponsiveLayout.windowSnapshot(context)
        val maxWidth = minOf(
            V2Ui.dp(context, boundedCanvasMaxDp(context)),
            snapshot.finalContentWidthPx,
        )
        return LinearLayout.LayoutParams(maxWidth, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    fun boundedCanvasHost(context: Context): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = boundedCanvasLayoutParams(context)
        }
    }

    fun modalScreenHeader(context: Context, title: String, subtitle: String? = null): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(
                TextView(context).apply {
                    text = title
                    textSize = 28f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirColors.Text.primary)
                    gravity = Gravity.CENTER
                },
            )
            subtitle?.let {
                addView(
                    TextView(context).apply {
                        text = it
                        textSize = 14f
                        setTextColor(HiAirColors.Text.secondary)
                        gravity = Gravity.CENTER
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
                bottomMargin = V2Ui.dp(context, HiAirSpacing.md)
            }
        }
    }

    fun orbOnlyHero(context: Context, orbSizeDp: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(HiAirComponents.brandOrbView(context, orbSizeDp))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = V2Ui.dp(context, HiAirSpacing.sm)
            }
        }
    }

    fun onboardingBrandHero(
        context: Context,
        orbSizeDp: Int,
        tagline: String,
        subtitle: String,
        compact: Boolean = false,
    ): LinearLayout {
        val wordmarkWidth = if (compact) 160 else 200
        val wordmarkHeight = if (compact) 32 else 40
        val subtitleBottom = if (compact) HiAirSpacing.xxs else HiAirSpacing.sm
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(HiAirComponents.brandOrbView(context, orbSizeDp).apply {
                (layoutParams as LinearLayout.LayoutParams).bottomMargin = V2Ui.dp(context, HiAirSpacing.xxs)
            })
            addView(HiAirComponents.brandWordmarkView(context, wordmarkWidth).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    V2Ui.dp(context, wordmarkHeight),
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    bottomMargin = V2Ui.dp(context, HiAirSpacing.xxs)
                }
            })
            addView(
                TextView(context).apply {
                    text = tagline
                    textSize = 14f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirColors.Cta.gradientStart)
                    gravity = Gravity.CENTER
                },
            )
            addView(
                TextView(context).apply {
                    text = subtitle
                    textSize = 13f
                    setTextColor(HiAirColors.Text.secondary)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = V2Ui.dp(context, HiAirSpacing.xxs)
                        bottomMargin = V2Ui.dp(context, subtitleBottom)
                    }
                },
            )
        }
    }

    fun paywallHeroBlock(context: Context, title: String, subtitle: String): LinearLayout {
        val widthDp = HiAirResponsiveLayout.screenWidthDp(context)
        val orbSize = when (HiAirResponsiveLayout.layoutMode(context)) {
            HiAirLayoutMode.COMPACT, HiAirLayoutMode.STANDARD -> 100
            HiAirLayoutMode.TABLET -> 112
            HiAirLayoutMode.EXPANDED -> 120
        }.coerceIn(88, HiAirScreenMetrics.heroOrbDp(widthDp) / 2)
        return HiAirComponents.glassAccentContainer(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(HiAirComponents.brandOrbView(context, orbSize))
            addView(
                TextView(context).apply {
                    text = title
                    textSize = 24f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirColors.Text.primary)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = V2Ui.dp(context, HiAirSpacing.sm)
                    }
                },
            )
            addView(
                TextView(context).apply {
                    text = subtitle
                    textSize = 13f
                    setTextColor(HiAirColors.Cta.gradientStart)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        topMargin = V2Ui.dp(context, HiAirSpacing.xxs)
                    }
                },
            )
        }
    }

    fun featureCard(
        context: Context,
        icon: String,
        title: String,
        body: String,
    ): LinearLayout {
        return HiAirComponents.glassAccentContainer(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val iconView = TextView(context).apply {
                text = icon
                textSize = 22f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    V2Ui.dp(context, 40),
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            }
            val copy = LinearLayout(context).apply {
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
            }
            addView(iconView)
            addView(copy)
        }
    }

    fun locationPermissionCard(context: Context, title: String, body: String): LinearLayout {
        return HiAirComponents.cardContainer(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                TextView(context).apply {
                    text = "📍"
                    textSize = 22f
                    layoutParams = LinearLayout.LayoutParams(
                        V2Ui.dp(context, 36),
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    )
                },
            )
            addView(
                LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        marginStart = V2Ui.dp(context, HiAirSpacing.sm)
                    }
                    addView(HiAirComponents.sectionTitle(context, title))
                    addView(V2Ui.styledSecondaryText(context, body).apply { textSize = 13f })
                },
            )
        }
    }

    fun shouldUseLandscapeSplit(context: Context): Boolean {
        val mode = HiAirResponsiveLayout.layoutMode(context)
        return isLandscape(context) && (mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED)
    }

    fun shouldCenterOnboardingPortrait(context: Context): Boolean {
        if (isLandscape(context)) return false
        val mode = HiAirResponsiveLayout.layoutMode(context)
        return mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED
    }

    /** Host for fillViewport scroll areas — vertically centers short portrait tablet stacks. */
    fun viewportCenteredHost(context: Context): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL or Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.MATCH_PARENT,
            )
        }
    }

    fun scrollTailPaddingPx(context: Context, navShell: View?): Int {
        return HiAirNavClearance.requiredBottomTailPx(context, navShell)
    }

    fun applyTitleAxisAlignment(titleView: TextView, context: Context) {
        val mode = HiAirResponsiveLayout.layoutMode(context)
        val center = mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED
        titleView.gravity = if (center) Gravity.CENTER_HORIZONTAL else Gravity.START
        titleView.textAlignment = if (center) View.TEXT_ALIGNMENT_CENTER else View.TEXT_ALIGNMENT_VIEW_START
        (titleView.layoutParams as? LinearLayout.LayoutParams)?.gravity =
            if (center) Gravity.CENTER_HORIZONTAL else Gravity.START
    }
}
