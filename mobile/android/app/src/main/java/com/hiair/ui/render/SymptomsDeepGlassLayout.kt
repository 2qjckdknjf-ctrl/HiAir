package com.hiair.ui.render

import android.graphics.Typeface
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.HiAirColors
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirRiskStyle
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.symptoms.SymptomLogState
import com.hiair.ui.theme.V2Ui
import java.util.Locale

/** Deep Glass V4 symptoms/health presentation for store screenshots and success states. */
internal object SymptomsDeepGlassLayout {
    fun render(ctx: RenderContext, state: SymptomLogState) {
        val activity = ctx.activity
        val body = ctx.bodyContainer
        val ru = ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")

        ctx.titleView.text = if (ru) "Как вы себя чувствуете?" else "How do you feel today?"
        body.addView(
            V2Ui.styledSecondaryText(
                activity,
                if (ru) "Персонализируйте рекомендации" else "Personalize your guidance",
            ).apply { textSize = 13f },
        )
        body.addView(buildMetricsRow(ctx, ru))
        body.addView(buildSymptomsSection(ctx, state, ru))
        body.addView(buildIntensitySection(ctx, state, ru))
        body.addView(buildEnergySection(ctx, state, ru))
        body.addView(buildInsightCard(ctx, ru))
        body.addView(buildCtaGroup(ctx, state))
        renderTaxonomyBelowFold(ctx, state)
    }

    private fun buildMetricsRow(ctx: RenderContext, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val tiles = listOf(
            metricTile(ctx, if (ru) "Пульс" else "Heart rate", "72 bpm", if (ru) "Норма" else "Normal", HiAirColors.Spectrum.magenta),
            metricTile(ctx, if (ru) "Шаги" else "Steps", "6,842", if (ru) "Цель 10 000" else "Goal 10,000", HiAirColors.Spectrum.cyan),
            metricTile(ctx, if (ru) "Сон" else "Sleep", "7h 42m", if (ru) "Хорошо" else "Good", HiAirColors.Spectrum.violet),
            metricTile(ctx, if (ru) "Восстановление" else "Recovery", if (ru) "Хорошо" else "Good", "75 HRV", HiAirColors.Spectrum.cyan),
        )
        val columns = HiAirResponsiveLayout.gridColumns(activity, maxColumns = 4).coerceAtMost(4)
        val host = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        HiAirResponsiveLayout.addGridRows(host, activity, columns, tiles, gapDp = HiAirSpacing.xs)
        return host.apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.md)
            }
        }
    }

    private fun metricTile(
        ctx: RenderContext,
        title: String,
        value: String,
        subtitle: String,
        accent: Int,
    ): LinearLayout {
        val activity = ctx.activity
        return HiAirComponents.cardContainer(activity).apply {
            addView(V2Ui.styledSecondaryText(activity, title).apply { textSize = 11f })
            addView(
                TextView(activity).apply {
                    text = value
                    textSize = 18f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Tokens.Text.primary)
                },
            )
            addView(
                V2Ui.styledSecondaryText(activity, subtitle).apply {
                    textSize = 11f
                    setTextColor(accent)
                },
            )
        }
    }

    private fun buildSymptomsSection(ctx: RenderContext, state: SymptomLogState, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val section = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        section.addView(
            HiAirComponents.sectionHeader(activity, ctx.l("title.symptoms")).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply {
                    topMargin = V2Ui.dp(activity, HiAirSpacing.md)
                }
            },
        )
        section.addView(
            V2Ui.styledSecondaryText(
                activity,
                if (ru) "Выберите все подходящие" else "Select all that apply",
            ).apply { textSize = 12f },
        )
        val chips = demoSymptomChips(ru).map { (label, selected) ->
            symptomChip(ctx, label, selected)
        }
        val columns = when (HiAirResponsiveLayout.layoutMode(activity)) {
            com.hiair.ui.design.HiAirLayoutMode.EXPANDED -> 4
            com.hiair.ui.design.HiAirLayoutMode.TABLET -> 3
            else -> 2
        }
        HiAirResponsiveLayout.addGridRows(section, activity, columns, chips, gapDp = HiAirSpacing.xs)
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

    private fun symptomChip(ctx: RenderContext, label: String, selected: Boolean): TextView {
        val activity = ctx.activity
        return TextView(activity).apply {
            text = label
            textSize = 14f
            gravity = Gravity.CENTER
            minHeight = V2Ui.dp(activity, 48)
            setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
            setPadding(V2Ui.dp(activity, 12), V2Ui.dp(activity, 10), V2Ui.dp(activity, 12), V2Ui.dp(activity, 10))
            background = HiAirComponents.tileBackground(activity, selected = selected)
            contentDescription = label
        }
    }

    private fun buildIntensitySection(ctx: RenderContext, state: SymptomLogState, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val severity = state.severity.coerceIn(1, 5)
        val card = HiAirComponents.cardContainer(activity).apply {
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.md)
            }
        }
        card.addView(V2Ui.styledBodyText(activity, ctx.l("symptoms.severity")).apply { setTypeface(typeface, Typeface.BOLD) })
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        (1..5).forEach { value ->
            val selected = severity == value
            row.addView(
                TextView(activity).apply {
                    text = value.toString()
                    textSize = 15f
                    gravity = Gravity.CENTER
                    minWidth = V2Ui.dp(activity, 44)
                    minHeight = V2Ui.dp(activity, 44)
                    setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
                    background = HiAirComponents.tileBackground(activity, selected = selected)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        marginEnd = V2Ui.dp(activity, HiAirSpacing.xs)
                    }
                },
            )
        }
        card.addView(row)
        card.addView(
            V2Ui.styledSecondaryText(
                activity,
                "${ctx.l("symptoms.severity.mild")} — ${ctx.l("symptoms.severity.severe")}",
            ).apply { textSize = 11f },
        )
        return card
    }

    private fun buildEnergySection(ctx: RenderContext, state: SymptomLogState, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val options = if (ru) listOf("Низкая", "Средняя", "Высокая") else listOf("Low", "Medium", "High")
        val card = HiAirComponents.cardContainer(activity).apply {
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.sm)
            }
        }
        card.addView(
            V2Ui.styledBodyText(activity, if (ru) "Как ваш уровень энергии?" else "How is your energy?").apply {
                setTypeface(typeface, Typeface.BOLD)
            },
        )
        val row = LinearLayout(activity).apply { orientation = LinearLayout.HORIZONTAL }
        options.forEachIndexed { index, label ->
            row.addView(
                TextView(activity).apply {
                    text = label
                    textSize = 13f
                    gravity = Gravity.CENTER
                    minHeight = V2Ui.dp(activity, 44)
                    setTextColor(if (index == 1) Tokens.Text.primary else Tokens.Text.secondary)
                    background = HiAirComponents.tileBackground(activity, selected = index == 1)
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        marginEnd = V2Ui.dp(activity, HiAirSpacing.xs)
                    }
                },
            )
        }
        card.addView(row)
        return card
    }

    private fun buildInsightCard(ctx: RenderContext, ru: Boolean): LinearLayout {
        val activity = ctx.activity
        val text = if (ru) {
            "Умная подсказка: обнаружены жара и повышенный пульс — снизьте нагрузку на улице во второй половине дня."
        } else {
            "Smart insight: Heat + elevated heart rate detected — reduce outdoor load this afternoon."
        }
        return HiAirComponents.glassAccentContainer(activity).apply {
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.md)
            }
            addView(V2Ui.styledBodyText(activity, text).apply {
                textSize = 14f
                setTextColor(HiAirColors.Risk.moderate)
            })
        }
    }

    private fun buildCtaGroup(ctx: RenderContext, state: SymptomLogState): LinearLayout {
        val activity = ctx.activity
        val group = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.lg)
            }
        }
        group.addView(
            HiAirComponents.primaryButton(activity, ctx.l("symptoms.submit")).apply {
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

    private fun renderTaxonomyBelowFold(ctx: RenderContext, state: SymptomLogState) {
        val taxonomy = state.taxonomy ?: return
        val activity = ctx.activity
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
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
            val columns = HiAirResponsiveLayout.gridColumns(activity, maxColumns = 3)
            HiAirResponsiveLayout.addGridRows(card, activity, columns, chips, gapDp = HiAirSpacing.xs)
            host.addView(card)
        }
        ctx.bodyContainer.addView(host)
    }
}
