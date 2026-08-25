package com.hiair.ui.render

import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.StoreScreenshotMode
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirGridLayout
import com.hiair.ui.design.HiAirLayoutMode
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirRiskStyle
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.design.markGeometry
import com.hiair.ui.planner.PlannerState
import com.hiair.ui.theme.V2Ui
import java.util.Calendar
import java.util.Locale

/** Deep Glass V4 planner presentation (presentation-only; uses existing planner state). */
internal object PlannerDeepGlassLayout {
    private data class DayPartCard(
        val title: String,
        val window: String,
        val level: String,
        val temp: String,
        val aqi: String,
        val note: String,
        val selected: Boolean = false,
    )

    private fun useTightStoreViewport(ctx: RenderContext): Boolean {
        if (!StoreScreenshotMode.active) return false
        val activity = ctx.activity
        val mode = HiAirResponsiveLayout.layoutMode(activity)
        return mode == HiAirLayoutMode.COMPACT ||
            (com.hiair.ui.design.HiAirV4Presentation.isLandscape(activity) &&
                (mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED))
    }

    fun render(ctx: RenderContext) {
        val ctx = ctx.withStoreContentRoot("planner")
        val activity = ctx.activity
        val body = ctx.bodyContainer
        val state = ctx.rootShell.plannerViewModel.state
        val ru = ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")

        ctx.titleView.text = ctx.l("title.planner")
        com.hiair.ui.design.HiAirV4Presentation.applyTitleAxisAlignment(ctx.titleView, activity)

        val canvas = com.hiair.ui.design.HiAirV4Presentation.boundedCanvasHost(activity)
        body.addView(canvas)
        canvas.addView(buildLocationChrome(ctx))
        val tight = useTightStoreViewport(ctx)
        canvas.addView(
            V2Ui.styledSecondaryText(activity, ctx.l("planner.subtitle")).apply {
                textSize = if (tight) 12f else 13f
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )
        canvas.addView(buildSummaryRow(ctx, state, ru))
        canvas.addView(buildChartCard(ctx, state, ru))
        canvas.addView(buildDayPartSection(ctx, state, ru))
        canvas.addView(buildUtilityRow(ctx, state, ru))
        canvas.addView(buildActionsSection(ctx, state, ru))
        canvas.addView(buildFooterActions(ctx, state))
    }

    private fun buildLocationChrome(ctx: RenderContext): LinearLayout {
        val activity = ctx.activity
        val ru = ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")
        val day = Calendar.getInstance().getDisplayName(Calendar.DAY_OF_WEEK, Calendar.LONG, Locale.getDefault())
        val locality = if (ru) "Барселона" else "Barcelona"
        val tight = useTightStoreViewport(ctx)
        return LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
            addView(V2Ui.styledSecondaryText(activity, "$locality • $day").apply {
                textSize = if (tight) 12f else 13f
                setTextColor(Tokens.Cta.start)
                gravity = Gravity.CENTER
            })
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = V2Ui.dp(activity, if (tight) HiAirSpacing.xxs else HiAirSpacing.sm)
            }
        }
    }

    private fun buildSummaryRow(ctx: RenderContext, state: PlannerState, ru: Boolean): View {
        val activity = ctx.activity
        val riskScore = 58
        val outdoor = state.safeWindows.firstOrNull()
            ?: if (ru) "18:40–20:20" else "18:40–20:20"
        val ventilation = state.ventilationWindows.firstOrNull()
            ?: if (ru) "21:00–22:30" else "21:00–22:30"
        val tiles = listOf(
            summaryTile(
                ctx,
                if (ru) "Риск" else "Risk",
                riskScore.toString(),
                if (ru) "УМЕРЕННЫЙ" else "MODERATE",
                HiAirComponents.riskAccentHex("moderate"),
            ),
            summaryTile(
                ctx,
                if (ru) "Лучшее окно" else "Best outdoor",
                outdoor.substringBefore(" ·").substringBefore(" ·"),
                if (ru) "Низкое загрязнение" else "Low pollution",
                HiAirComponents.riskAccentHex("low"),
            ),
            summaryTile(
                ctx,
                if (ru) "Проветривание" else "Ventilation",
                ventilation.substringBefore(" ·").substringBefore(" ·"),
                if (ru) "Хороший обмен" else "Good air exchange",
                HiAirComponents.riskAccentHex("moderate"),
            ),
        )
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.PLANNER_SUMMARY_GRID)
        }
        HiAirGridLayout.addAdaptiveGridRows(host, activity, requestedColumns = 3, tiles)
        return HiAirComponents.cardContainer(activity).apply { addView(host) }
    }

    private fun summaryTile(
        ctx: RenderContext,
        label: String,
        value: String,
        caption: String,
        accentHex: String,
    ): LinearLayout {
        val activity = ctx.activity
        val tight = useTightStoreViewport(ctx)
        return HiAirComponents.cardContainer(activity).apply {
            orientation = LinearLayout.VERTICAL
            addView(V2Ui.styledSecondaryText(activity, label).apply { textSize = if (tight) 11f else 12f })
            addView(
                TextView(activity).apply {
                    text = value
                    textSize = if (tight) 17f else 20f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Tokens.Text.primary)
                },
            )
            addView(V2Ui.styledSecondaryText(activity, caption).apply {
                textSize = if (tight) 10f else 11f
                setTextColor(HiAirRiskStyle.colorForLevel("moderate"))
            })
        }
    }

    private fun buildChartCard(ctx: RenderContext, state: PlannerState, ru: Boolean): View {
        val activity = ctx.activity
        val card = HiAirComponents.cardContainer(activity).markGeometry(HiAirGeometryMarkers.PLANNER_CHART).apply {
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                width = LinearLayout.LayoutParams.MATCH_PARENT
            }
        }
        card.addView(
            V2Ui.styledBodyText(activity, if (ru) "Качество воздуха 24 ч" else "24-hour air quality").apply {
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
            },
        )
        val selector = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            addView(selectorChip(ctx, "AQI", selected = true))
            addView(selectorChip(ctx, if (ru) "Пыльца" else "Pollen", selected = false))
        }
        card.addView(selector)
        val chart = PlannerHourlyChartView(activity)
        val tight = useTightStoreViewport(ctx)
        val chartHeightDp = when {
            tight && com.hiair.ui.design.HiAirV4Presentation.isLandscape(ctx.activity) -> 48
            tight -> 56
            com.hiair.ui.design.HiAirV4Presentation.isLandscape(ctx.activity) -> 64
            com.hiair.ui.design.HiAirResponsiveLayout.layoutMode(ctx.activity) == com.hiair.ui.design.HiAirLayoutMode.COMPACT -> 72
            else -> 88
        }
        chart.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            V2Ui.dp(activity, chartHeightDp),
        ).apply {
            topMargin = V2Ui.dp(activity, HiAirSpacing.sm)
        }
        val hourly = if (com.hiair.StoreScreenshotMode.active) {
            demoHourly()
        } else {
            state.hourly.ifEmpty { demoHourly() }
        }
        chart.bindHourlyRisks(hourly.map { it.substringAfterLast(":", "moderate").trim() })
        card.addView(chart)
        if (!tight) {
            state.peakLine.takeIf { it.isNotBlank() }?.let {
                card.addView(V2Ui.styledSecondaryText(activity, it).apply { textSize = 12f })
            }
        }
        return card
    }

    private fun selectorChip(ctx: RenderContext, label: String, selected: Boolean): TextView {
        val activity = ctx.activity
        return TextView(activity).apply {
            text = label
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(if (selected) Tokens.Text.primary else Tokens.Text.secondary)
            setPadding(V2Ui.dp(activity, 12), V2Ui.dp(activity, 6), V2Ui.dp(activity, 12), V2Ui.dp(activity, 6))
            background = HiAirComponents.tileBackground(activity, selected = selected)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = V2Ui.dp(activity, HiAirSpacing.xs)
            }
        }
    }

    private fun buildDayPartSection(ctx: RenderContext, state: PlannerState, ru: Boolean): View {
        val activity = ctx.activity
        val cards = dayParts(ru).map { part ->
            dayPartCard(ctx, part)
        }
        val requestedColumns = when (com.hiair.ui.design.HiAirResponsiveLayout.layoutMode(activity)) {
            com.hiair.ui.design.HiAirLayoutMode.COMPACT,
            com.hiair.ui.design.HiAirLayoutMode.STANDARD,
            -> 2
            com.hiair.ui.design.HiAirLayoutMode.TABLET -> 2
            com.hiair.ui.design.HiAirLayoutMode.EXPANDED -> 4
        }
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.PLANNER_DAYPART_GRID)
        }
        HiAirGridLayout.addAdaptiveGridRows(host, activity, requestedColumns, cards, gapDp = HiAirSpacing.sm)
        return host
    }

    private fun dayParts(ru: Boolean): List<DayPartCard> = listOf(
        DayPartCard(
            if (ru) "Утро" else "Morning",
            "06:00–12:00",
            if (ru) "УМЕРЕННО" else "MODERATE",
            "21°",
            "AQI 62",
            if (ru) "Носите солнцезащитные очки" else "Wear sunglasses outdoors",
        ),
        DayPartCard(
            if (ru) "День" else "Day",
            "12:00–18:00",
            if (ru) "ВЫСОКИЙ" else "HIGH",
            "28°",
            "AQI 78",
            if (ru) "Ограничьте активность на улице" else "Limit intense outdoor activity",
        ),
        DayPartCard(
            if (ru) "Вечер" else "Evening",
            "18:00–24:00",
            if (ru) "НИЗКИЙ" else "LOW",
            "24°",
            "AQI 32",
            if (ru) "Отличное время для прогулки" else "Perfect time for a walk",
            selected = true,
        ),
        DayPartCard(
            if (ru) "Ночь" else "Night",
            "00:00–06:00",
            if (ru) "НИЗКИЙ" else "LOW",
            "18°",
            "AQI 25",
            if (ru) "Можно проветривать перед сном" else "Great air quality overnight",
        ),
    )

    private fun dayPartCard(ctx: RenderContext, part: DayPartCard): LinearLayout {
        val activity = ctx.activity
        val tight = useTightStoreViewport(ctx)
        val emphasis = if (part.selected) {
            com.hiair.ui.design.HiAirV4Glass.Emphasis.SELECTED
        } else {
            com.hiair.ui.design.HiAirV4Glass.Emphasis.DEFAULT
        }
        return com.hiair.ui.design.HiAirV4Glass.sectionCard(activity, emphasis).apply {
            addView(V2Ui.styledBodyText(activity, part.title).apply {
                setTypeface(typeface, Typeface.BOLD)
                if (tight) textSize = 14f
            })
            addView(V2Ui.styledSecondaryText(activity, part.window).apply { textSize = if (tight) 11f else 12f })
            addView(
                TextView(activity).apply {
                    text = part.level
                    textSize = if (tight) 10f else 11f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(HiAirRiskStyle.colorForLevel(part.level.lowercase(Locale.ROOT)))
                },
            )
            addView(V2Ui.styledBodyText(activity, "${part.temp} · ${part.aqi}").apply { textSize = if (tight) 12f else 13f })
            addView(V2Ui.styledSecondaryText(activity, part.note).apply { textSize = if (tight) 11f else 12f })
        }
    }

    private fun buildUtilityRow(ctx: RenderContext, state: PlannerState, ru: Boolean): View {
        val activity = ctx.activity
        val vent = state.ventilationWindows.firstOrNull() ?: "21:00–22:30"
        val hydration = if (ru) "Выпейте 1 стакан воды" else "Drink 1 glass of water"
        val tiles = listOf(
            utilityCard(ctx, ctx.l("planner.window.ventilation"), vent, if (ru) "Хороший обмен" else "Good air exchange"),
            utilityCard(ctx, if (ru) "Гидратация" else "Hydration", hydration, if (ru) "Следующее напоминание 12:00" else "Next reminder at 12:00"),
        )
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.PLANNER_UTILITY_ROW)
        }
        HiAirGridLayout.addAdaptiveGridRows(host, activity, requestedColumns = 2, tiles)
        return host.apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, if (useTightStoreViewport(ctx)) HiAirSpacing.sm else HiAirSpacing.md)
            }
        }
    }

    private fun utilityCard(ctx: RenderContext, title: String, value: String, caption: String): LinearLayout {
        val activity = ctx.activity
        return HiAirComponents.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, title).apply { setTypeface(typeface, Typeface.BOLD) })
            addView(V2Ui.styledBodyText(activity, value).apply { textSize = 15f })
            addView(V2Ui.styledSecondaryText(activity, caption).apply { textSize = 12f })
        }
    }

    private fun buildActionsSection(ctx: RenderContext, state: PlannerState, ru: Boolean): View {
        val activity = ctx.activity
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.md)
            }
        }
        host.addView(
            V2Ui.styledBodyText(activity, if (ru) "Рекомендуемые действия" else "Recommended actions").apply {
                setTypeface(typeface, Typeface.BOLD)
            },
        )
        val walkTime = state.activityRecommendedStart.ifBlank { "19:00" }
        val actions = listOf(
            actionCard(
                ctx,
                if (ru) "Прогулка в $walkTime" else "Walk outside at $walkTime",
                if (ru) "Низкое загрязнение и комфортная температура" else "Lower pollution and comfortable temperature",
                if (ru) "Добавить в календарь" else "Add to calendar",
            ),
            actionCard(
                ctx,
                if (ru) "Открыть окна после 21:00" else "Open windows after 21:00",
                if (ru) "Естественное проветривание улучшит воздух" else "Natural ventilation improves indoor air",
                if (ru) "Напомнить" else "Set reminder",
            ),
        )
        HiAirGridLayout.addAdaptiveGridRows(
            host,
            activity,
            requestedColumns = 2,
            views = actions,
        )
        return host
    }

    private fun actionCard(ctx: RenderContext, title: String, body: String, cta: String): LinearLayout {
        val activity = ctx.activity
        return HiAirComponents.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, title).apply { setTypeface(typeface, Typeface.BOLD) })
            addView(V2Ui.styledSecondaryText(activity, body).apply { textSize = 12f })
            addView(HiAirComponents.secondaryButton(activity, cta))
        }
    }

    private fun buildFooterActions(ctx: RenderContext, state: PlannerState): View {
        val activity = ctx.activity
        val group = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = HiAirResponsiveLayout.readingColumnLayoutParams(activity).apply {
                topMargin = V2Ui.dp(activity, HiAirSpacing.lg)
            }
        }
        group.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("planner.refresh")).apply {
                setOnClickListener {
                    ctx.rootShell.plannerViewModel.hasAttemptedAutoLoad = false
                    ctx.rerender()
                }
            },
        )
        group.addView(
            HiAirComponents.primaryButton(activity, ctx.l("planner.apply")).apply {
                markGeometry(HiAirGeometryMarkers.PLANNER_FOOTER_CTA)
                setOnClickListener {
                    ctx.rootShell.openDashboard()
                    ctx.rerender()
                }
            },
        )
        return group
    }

    private fun demoHourly(): List<String> {
        return (0..23).map { hour ->
            val risk = when (hour) {
                in 6..9 -> "low"
                in 10..13 -> "moderate"
                in 14..17 -> "high"
                in 18..20 -> "low"
                in 21..23 -> "moderate"
                else -> "low"
            }
            String.format(Locale.US, "%02d:00", hour) + ":$risk"
        }
    }
}
