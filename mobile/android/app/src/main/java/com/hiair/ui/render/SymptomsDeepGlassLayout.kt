package com.hiair.ui.render

import android.graphics.Typeface
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.StoreScreenshotMode
import com.hiair.StoreScreenshotReadiness
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.design.HiAirColors
import com.hiair.R
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirV4Glass
import com.hiair.ui.design.HiAirGridLayout
import com.hiair.ui.design.HiAirLayoutMode
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirV4Presentation
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.design.markGeometry
import com.hiair.ui.symptoms.SymptomLogState
import com.hiair.ui.theme.V2Ui
import java.util.Locale

/** Deep Glass V4 symptoms/health presentation for store screenshots and success states. */
internal object SymptomsDeepGlassLayout {
    private fun useTightPhoneViewport(ctx: RenderContext): Boolean {
        if (!StoreScreenshotMode.active) return false
        val activity = ctx.activity
        return !HiAirV4Presentation.shouldUseLandscapeSplit(activity) &&
            HiAirResponsiveLayout.layoutMode(activity) == HiAirLayoutMode.COMPACT
    }

    fun render(ctx: RenderContext, state: SymptomLogState) {
        val ctx = ctx.withStoreContentRoot("symptoms")
        val activity = ctx.activity
        val body = ctx.bodyContainer
        val ru = ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")

        ctx.titleView.text = if (ru) "Как вы себя чувствуете?" else "How do you feel today?"
        com.hiair.ui.design.HiAirV4Presentation.applyTitleAxisAlignment(ctx.titleView, activity)

        val canvas = com.hiair.ui.design.HiAirV4Presentation.boundedCanvasHost(activity).apply {
            contentDescription = StoreScreenshotReadiness.SYMPTOMS_CONTENT_ROOT
        }
        body.addView(canvas)

        canvas.addView(
            V2Ui.styledSecondaryText(
                activity,
                if (ru) "Персонализируйте рекомендации" else "Personalize your guidance",
            ).apply {
                textSize = 13f
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )
        if (HiAirV4Presentation.shouldUseLandscapeSplit(activity)) {
            val landscapeColumn = true
            val row = LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.TOP
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            }
            val left = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            }
            val right = LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = V2Ui.dp(activity, HiAirSpacing.md)
                }
            }
            left.addView(buildRecoveryHero(ctx, ru, landscapeColumn))
            left.addView(buildMetricsRow(ctx, ru))
            left.addView(buildSymptomsSection(ctx, state, ru))
            right.addView(buildIntensitySection(ctx, ru, landscapeColumn))
            right.addView(buildEnergySection(ctx, ru, landscapeColumn))
            right.addView(buildInsightCard(ctx, ru, landscapeColumn))
            right.addView(buildCtaGroup(ctx, state, landscapeColumn))
            row.addView(left)
            row.addView(right)
            canvas.addView(row)
        } else {
            canvas.addView(buildRecoveryHero(ctx, ru, landscapeColumn = false))
            canvas.addView(buildMetricsRow(ctx, ru))
            canvas.addView(buildSymptomsSection(ctx, state, ru))
            canvas.addView(buildIntensitySection(ctx, ru, landscapeColumn = false))
            canvas.addView(buildEnergySection(ctx, ru, landscapeColumn = false))
            canvas.addView(buildInsightCard(ctx, ru, landscapeColumn = false))
            canvas.addView(buildCtaGroup(ctx, state, landscapeColumn = false))
        }
        renderTaxonomyBelowFold(ctx, state, canvas)
        canvas.addView(V2Ui.spacer(activity, HiAirSpacing.xxl))
    }

    private fun sectionLayoutParams(
        ctx: RenderContext,
        landscapeColumn: Boolean,
        topMarginDp: Int = HiAirSpacing.md,
    ): LinearLayout.LayoutParams {
        val activity = ctx.activity
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            if (topMarginDp > 0) {
                topMargin = V2Ui.dp(activity, topMarginDp)
            }
            if (!landscapeColumn) {
                val maxWidth = minOf(
                    V2Ui.dp(activity, com.hiair.ui.design.HiAirScreenMetrics.readingColumnMaxDp),
                    HiAirResponsiveLayout.availableContentWidthPx(activity),
                )
                width = maxWidth
                gravity = Gravity.CENTER_HORIZONTAL
            }
        }
    }

    private fun buildRecoveryHero(ctx: RenderContext, ru: Boolean, landscapeColumn: Boolean): LinearLayout {
        val activity = ctx.activity
        val tight = useTightPhoneViewport(ctx)
        return HiAirComponents.cardContainer(activity).apply {
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_RECOVERY_HERO)
            layoutParams = sectionLayoutParams(
                ctx,
                landscapeColumn,
                topMarginDp = if (tight) HiAirSpacing.xs else HiAirSpacing.md,
            )
            addView(
                V2Ui.styledBodyText(
                    activity,
                    if (ru) "Восстановление сегодня" else "Recovery today",
                ).apply {
                    setTypeface(typeface, Typeface.BOLD)
                    if (tight) textSize = 14f
                },
            )
            addView(
                V2Ui.styledSecondaryText(
                    activity,
                    if (ru) "75 HRV · хорошее восстановление · низкая нагрузка" else "75 HRV · good recovery · low personal load",
                ).apply { textSize = if (tight) 12f else 13f },
            )
        }
    }

    private fun buildMetricsRow(ctx: RenderContext, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val tight = useTightPhoneViewport(ctx)
        val tiles = listOf(
            metricTile(ctx, R.drawable.ic_v4_heart, if (ru) "Пульс" else "Heart rate", "72 bpm", if (ru) "Норма" else "Normal", HiAirColors.Spectrum.magenta),
            metricTile(ctx, R.drawable.ic_v4_steps, if (ru) "Шаги" else "Steps", "6,842", if (ru) "Цель 10 000" else "Goal 10,000", HiAirColors.Spectrum.cyan),
            metricTile(ctx, R.drawable.ic_v4_sleep, if (ru) "Сон" else "Sleep", "7h 42m", if (ru) "Хорошо" else "Good", HiAirColors.Spectrum.violet),
            metricTile(ctx, R.drawable.ic_v4_recovery, if (ru) "Восстановление" else "Recovery", if (ru) "Хорошо" else "Good", "75 HRV", HiAirColors.Spectrum.cyan),
        )
        val requestedColumns = when {
            HiAirV4Presentation.shouldUseLandscapeSplit(activity) -> 2
            HiAirResponsiveLayout.layoutMode(activity) == com.hiair.ui.design.HiAirLayoutMode.EXPANDED -> 4
            HiAirResponsiveLayout.layoutMode(activity) == com.hiair.ui.design.HiAirLayoutMode.TABLET -> 2
            else -> 2
        }
        val host = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        HiAirGridLayout.addAdaptiveGridRows(
            host,
            activity,
            requestedColumns = requestedColumns,
            views = tiles,
            gapDp = HiAirSpacing.xs,
            minItemWidthDp = HiAirGridLayout.MIN_CARD_WIDTH_DP,
        )
        return host.apply {
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_METRICS_GRID)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, if (tight) HiAirSpacing.xs else HiAirSpacing.md)
            }
        }
    }

    private fun metricTile(
        ctx: RenderContext,
        iconRes: Int,
        title: String,
        value: String,
        subtitle: String,
        accent: Int,
    ): LinearLayout {
        val activity = ctx.activity
        val tight = useTightPhoneViewport(ctx)
        return HiAirV4Glass.sectionCard(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(HiAirV4Glass.iconContainer(activity, iconRes, accent))
            addView(V2Ui.styledSecondaryText(activity, title).apply {
                textSize = 11f
                gravity = Gravity.CENTER_HORIZONTAL
            })
            addView(
                TextView(activity).apply {
                    text = value
                    textSize = if (tight) 16f else 18f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Tokens.Text.primary)
                    gravity = Gravity.CENTER_HORIZONTAL
                },
            )
            addView(
                V2Ui.styledSecondaryText(activity, subtitle).apply {
                    textSize = 11f
                    setTextColor(accent)
                    gravity = Gravity.CENTER_HORIZONTAL
                },
            )
        }
    }

    private fun buildSymptomsSection(ctx: RenderContext, state: SymptomLogState, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val tight = useTightPhoneViewport(ctx)
        val section = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_CHIP_GRID)
        }
        section.addView(
            HiAirComponents.sectionHeader(activity, ctx.l("title.symptoms")).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    topMargin = V2Ui.dp(activity, if (tight) HiAirSpacing.xs else HiAirSpacing.md)
                }
            },
        )
        section.addView(
            V2Ui.styledSecondaryText(
                activity,
                if (ru) "Выберите все подходящие" else "Select all that apply",
            ).apply { textSize = if (tight) 11f else 12f },
        )
        val chips = demoSymptomChips(ru).map { (label, selected) ->
            symptomChip(ctx, label, selected, tight)
        }
        val requestedColumns = when (HiAirResponsiveLayout.layoutMode(activity)) {
            com.hiair.ui.design.HiAirLayoutMode.EXPANDED ->
                if (HiAirV4Presentation.isLandscape(activity)) 2 else 3
            com.hiair.ui.design.HiAirLayoutMode.TABLET -> 2
            else -> 2
        }
        HiAirGridLayout.addAdaptiveGridRows(
            section,
            activity,
            requestedColumns = requestedColumns,
            views = chips,
            gapDp = HiAirSpacing.xs,
            minItemWidthDp = HiAirGridLayout.MIN_CHIP_WIDTH_DP,
        )
        return section
    }

    private fun demoSymptomChips(ru: Boolean): List<Pair<String, Boolean>> {
        return if (ru) {
            listOf(
                "Дыхание" to true,
                "Усталость" to true,
                "Аллергия" to true,
                "Головная боль" to false,
                "Кашель" to false,
                "Головокружение" to false,
            )
        } else {
            listOf(
                "Breathing" to true,
                "Fatigue" to true,
                "Allergy" to true,
                "Headache" to false,
                "Cough" to false,
                "Dizziness" to false,
            )
        }
    }

    private fun symptomChip(ctx: RenderContext, label: String, selected: Boolean, tight: Boolean = false): TextView {
        val activity = ctx.activity
        return TextView(activity).apply {
            text = if (selected) "✓ $label" else label
            textSize = if (tight) 13f else 14f
            gravity = Gravity.CENTER
            minHeight = V2Ui.dp(activity, if (tight) 36 else 44)
            setTypeface(typeface, if (selected) Typeface.BOLD else Typeface.NORMAL)
            setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
            setPadding(
                V2Ui.dp(activity, 12),
                V2Ui.dp(activity, if (tight) 6 else 10),
                V2Ui.dp(activity, 12),
                V2Ui.dp(activity, if (tight) 6 else 10),
            )
            background = if (selected) {
                HiAirV4Glass.surfaceBackground(activity, HiAirV4Glass.Emphasis.SELECTED)
            } else {
                HiAirComponents.tileBackground(activity, selected = false)
            }
            contentDescription = label
        }
    }

    private fun buildIntensitySection(ctx: RenderContext, ru: Boolean, landscapeColumn: Boolean): LinearLayout {
        val activity = ctx.activity
        val tight = useTightPhoneViewport(ctx)
        val severity = ctx.rootShell.symptomLogViewModel.state.severity.coerceIn(1, 5)
        val card = HiAirComponents.cardContainer(activity).apply {
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_INTENSITY)
            layoutParams = sectionLayoutParams(
                ctx,
                landscapeColumn,
                topMarginDp = if (tight) HiAirSpacing.xs else HiAirSpacing.md,
            )
        }
        card.addView(V2Ui.styledBodyText(activity, ctx.l("symptoms.severity")).apply { setTypeface(typeface, Typeface.BOLD) })
        val labels = (1..5).map { it.toString() }
        card.addView(
            HiAirV4Glass.segmentedControl(activity, labels, severity - 1),
        )
        card.addView(
            V2Ui.styledSecondaryText(
                activity,
                "${ctx.l("symptoms.severity.mild")} — ${ctx.l("symptoms.severity.severe")}",
            ).apply { textSize = 11f },
        )
        return card
    }

    private fun buildEnergySection(ctx: RenderContext, ru: Boolean, landscapeColumn: Boolean): LinearLayout {
        val activity = ctx.activity
        val options = if (ru) listOf("Низкая", "Средняя", "Высокая") else listOf("Low", "Medium", "High")
        val card = HiAirComponents.cardContainer(activity).apply {
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_ENERGY)
            layoutParams = sectionLayoutParams(ctx, landscapeColumn, topMarginDp = HiAirSpacing.sm)
        }
        card.addView(
            V2Ui.styledBodyText(activity, if (ru) "Как ваш уровень энергии?" else "How is your energy?").apply {
                setTypeface(typeface, Typeface.BOLD)
            },
        )
        card.addView(HiAirV4Glass.segmentedControl(activity, options, selectedIndex = 1))
        return card
    }

    private fun buildInsightCard(ctx: RenderContext, ru: Boolean, landscapeColumn: Boolean): LinearLayout {
        val activity = ctx.activity
        val text = if (ru) {
            "Умная подсказка: обнаружены жара и повышенный пульс — снизьте нагрузку на улице во второй половине дня."
        } else {
            "Smart insight: Heat + elevated heart rate detected — reduce outdoor load this afternoon."
        }
        return HiAirComponents.glassAccentContainer(activity).apply {
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_INSIGHT)
            layoutParams = sectionLayoutParams(ctx, landscapeColumn)
            addView(V2Ui.styledBodyText(activity, text).apply {
                textSize = 14f
                setTextColor(HiAirColors.Risk.moderate)
            })
        }
    }

    private fun buildCtaGroup(ctx: RenderContext, state: SymptomLogState, landscapeColumn: Boolean): LinearLayout {
        val activity = ctx.activity
        val group = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = sectionLayoutParams(ctx, landscapeColumn, topMarginDp = HiAirSpacing.lg)
        }
        group.addView(
            HiAirComponents.primaryButton(activity, ctx.l("symptoms.submit")).apply {
                markGeometry(HiAirGeometryMarkers.SYMPTOMS_PRIMARY_CTA)
                isEnabled = true
            },
        )
        group.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("nav.insights")).apply {
                setOnClickListener {
                    ctx.rootShell.openInsights()
                    ctx.rerender()
                }
            },
        )
        return group
    }

    private fun renderTaxonomyBelowFold(ctx: RenderContext, state: SymptomLogState, contentRoot: LinearLayout) {
        val taxonomy = state.taxonomy ?: return
        val activity = ctx.activity
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.SYMPTOMS_TAXONOMY)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.lg)
            }
        }
        taxonomy.categories.forEach { category ->
            val card = HiAirComponents.cardContainer(activity)
            card.addView(
                V2Ui.styledBodyText(activity, category.label).apply {
                    setTypeface(typeface, Typeface.BOLD)
                },
            )
            val chips = category.symptoms.map { item ->
                symptomChip(ctx, item.label, state.selectedType == item.symptomType)
            }
            HiAirGridLayout.addAdaptiveGridRows(
                card,
                activity,
                requestedColumns = 3,
                views = chips,
                gapDp = HiAirSpacing.xs,
                minItemWidthDp = HiAirGridLayout.MIN_CHIP_WIDTH_DP,
            )
            host.addView(card)
        }
        contentRoot.addView(host)
    }
}
