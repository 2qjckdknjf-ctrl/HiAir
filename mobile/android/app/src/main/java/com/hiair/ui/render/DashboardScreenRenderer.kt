package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import com.hiair.health.WearableHealthHost
import com.hiair.location.LocationBootstrapHost
import com.hiair.ui.DashboardState
import com.hiair.ui.DashboardStatus
import com.hiair.ui.DashboardViewModel
import com.hiair.ui.family.FamilyRiskParser
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirRiskStyle
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui
import java.util.Locale

internal object DashboardScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        (activity as? WearableHealthHost)?.syncWearablesIfPermitted()
        val bodyContainer = ctx.bodyContainer

        ctx.titleView.text = ctx.l("dashboard.greeting_neutral")
        bodyContainer.addView(
            HiAirComponents.brandHeader(
                activity,
                compact = true,
                showOrb = true,
                orbSizeDp = 44,
            )
        )

        when (ctx.rootShell.dashboardViewModel.state.status) {
            DashboardStatus.INITIAL -> {
                ctx.rootShell.dashboardViewModel.markLoading()
                renderLoading(ctx)
                triggerLoad(ctx, isRetry = false)
            }
            DashboardStatus.LOADING -> renderLoading(ctx)
            DashboardStatus.SUCCESS -> renderSuccess(ctx, ctx.rootShell.dashboardViewModel.state)
            DashboardStatus.EMPTY -> renderEmpty(ctx)
            DashboardStatus.ERROR -> renderProblem(ctx, offline = false)
            DashboardStatus.OFFLINE -> renderProblem(ctx, offline = true)
        }
    }

    private fun triggerLoad(ctx: RenderContext, isRetry: Boolean) {
        val rootShell = ctx.rootShell
        val activity = ctx.activity
        val startLoad = Runnable {
            Thread {
                val profileId = rootShell.settingsViewModel.ensureProfile()
                val settings = rootShell.settingsViewModel.state
                rootShell.dashboardViewModel.load(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                    profileId = profileId,
                    preferredLanguage = settings.preferredLanguage,
                    isRetry = isRetry,
                    onRiskReady = {
                        activity.runOnUiThread {
                            ctx.persistSession()
                            ctx.rerender()
                        }
                    },
                )
                activity.runOnUiThread {
                    ctx.persistSession()
                    ctx.rerender()
                }
            }.start()
        }
        val host = activity as? LocationBootstrapHost
        if (host != null && !rootShell.settingsViewModel.hasValidLocation()) {
            host.bootstrapLocation { startLoad.run() }
        } else {
            startLoad.run()
        }
    }

    private fun renderLoading(ctx: RenderContext) {
        val activity = ctx.activity
        ctx.bodyContainer.addView(
            HiAirComponents.cardContainer(activity).apply {
                addView(
                    ProgressBar(activity).apply {
                        isIndeterminate = true
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                        ).apply { gravity = Gravity.CENTER_HORIZONTAL }
                    }
                )
                addView(V2Ui.spacer(activity, 10))
                addView(
                    V2Ui.styledSecondaryText(activity, ctx.l("dashboard.loading")).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                    }
                )
            }
        )
    }

    private fun renderEmpty(ctx: RenderContext) {
        val activity = ctx.activity
        ctx.bodyContainer.addView(
            HiAirComponents.cardContainer(activity).apply {
                addView(HiAirComponents.sectionTitle(activity, ctx.l("dashboard.empty_title")))
                addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.empty_body")))
                addView(V2Ui.spacer(activity, 10))
                addView(
                    HiAirComponents.primaryButton(activity, ctx.l("dashboard.empty_action")).apply {
                        setOnClickListener {
                            ctx.rootShell.openSettings()
                            ctx.rerender()
                        }
                    }
                )
            }
        )
    }

    private fun renderProblem(ctx: RenderContext, offline: Boolean) {
        val activity = ctx.activity
        val messageKey = if (offline) "dashboard.offline" else "dashboard.error"
        ctx.bodyContainer.addView(
            HiAirComponents.cardContainer(activity).apply {
                addView(HiAirComponents.sectionTitle(activity, ctx.l("dashboard.problem_title")))
                addView(V2Ui.styledSecondaryText(activity, ctx.l(messageKey)))
                addView(V2Ui.spacer(activity, 10))
                addView(
                    HiAirComponents.primaryButton(activity, ctx.l("dashboard.retry")).apply {
                        setOnClickListener {
                            ctx.rootShell.dashboardViewModel.markLoading()
                            ctx.rerender()
                            triggerLoad(ctx, isRetry = true)
                        }
                    }
                )
            }
        )
    }

    private fun renderSuccess(ctx: RenderContext, state: DashboardState) {
        val activity = ctx.activity
        val bodyContainer = ctx.bodyContainer
        val level = state.riskLevel ?: return

        val riskGauge = HiAirComponents.riskGaugeView(
            activity,
            state.riskScore ?: DashboardViewModel.scoreForLevel(level),
            moodLabel(ctx, level),
            level,
        )
        val riskDetailText = buildString {
            state.headline?.let { append(it) }
            state.explanation?.let {
                if (isNotEmpty()) append("\n")
                append(it)
            }
        }.ifBlank { ctx.l("dashboard.reason_unavailable") }
        val riskDetail = V2Ui.styledSecondaryText(activity, riskDetailText).apply {
            textSize = 13f
            gravity = Gravity.CENTER_HORIZONTAL
        }

        bodyContainer.addView(
            HiAirComponents.cardContainer(activity).apply {
                addView(HiAirComponents.sectionTitle(activity, ctx.l("dashboard.current_risk_title")))
                addView(riskGauge)
                addView(riskDetail)
                dataSourceLabel(ctx, state)?.let { addView(it) }
            }
        )

        airMetricsCard(ctx, state)?.let { bodyContainer.addView(it) }
        hazardsCard(ctx, state)?.let { bodyContainer.addView(it) }
        familyRiskCard(ctx, state)?.let { bodyContainer.addView(it) }
        protectedDayCard(ctx, state)?.let { bodyContainer.addView(it) }
        if (state.wearableConnected) {
            bodyContainer.addView(
                HealthTodayMetricsRenderer.render(
                    ctx = ctx,
                    summaryRaw = state.healthSummaryRaw,
                    loadLevel = state.wearableLoadLevel,
                    loadExplanation = state.wearableSummary,
                ),
            )
        } else {
            bodyContainer.addView(wearableCard(ctx, state))
        }
        bodyContainer.addView(actionsCard(ctx, state))
        bodyContainer.addView(safeWindowsCard(ctx, state))

        bodyContainer.addView(
            HiAirComponents.primaryButton(activity, ctx.l("dashboard.recompute")).apply {
                setOnClickListener {
                    ctx.rootShell.dashboardViewModel.markLoading()
                    ctx.rerender()
                    triggerLoad(ctx, isRetry = false)
                }
            }
        )
        bodyContainer.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("dashboard.log_symptoms")).apply {
                setOnClickListener {
                    ctx.rootShell.openSymptoms()
                    ctx.rerender()
                }
            }
        )
        attachAtmosphericOverlay(ctx, state)
    }

    private fun attachAtmosphericOverlay(ctx: RenderContext, state: DashboardState) {
        val pm25 = state.pm25 ?: return
        val level = state.riskLevel ?: return
        val overlay = ctx.overlayContainer
        overlay.addView(
            AtmosphericParticlesView(ctx.activity).apply {
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                )
                setPm25(pm25)
                setTintColor(HiAirRiskStyle.colorForLevel(level))
                isClickable = false
                isFocusable = false
            },
        )
    }

    private fun dataSourceLabel(ctx: RenderContext, state: DashboardState): TextView? {
        val source = state.freshness ?: state.dataSource ?: return null
        val key = when {
            source.equals("live", ignoreCase = true) -> "planner.freshness.live"
            source.equals("cached", ignoreCase = true) -> "planner.freshness.cached"
            source.equals("stale", ignoreCase = true) -> "planner.freshness.stale"
            source.equals("sample", ignoreCase = true) -> "dashboard.source_estimated"
            else -> "dashboard.source_live"
        }
        return V2Ui.styledSecondaryText(ctx.activity, ctx.l(key)).apply {
            textSize = 11f
            gravity = Gravity.CENTER_HORIZONTAL
            setTextColor(Tokens.Text.tertiary)
        }
    }

    private fun hazardsCard(ctx: RenderContext, state: DashboardState): View? {
        val overall = state.hazardsOverallLevel ?: return null
        if (state.hazardLines.isEmpty()) return null
        val activity = ctx.activity
        val unavailable = ctx.l("dashboard.metric.unavailable")
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("hazards.title")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            addView(
                metricRow(
                    ctx,
                    ctx.l("hazards.overall"),
                    "${hazardLevelLabel(ctx, overall)} (${state.hazardsOverallScore ?: 0})",
                ),
            )
            state.hazardLines.filter { it.available }.forEach { line ->
                addView(
                    metricRow(
                        ctx,
                        hazardTypeLabel(ctx, line.hazard),
                        "${hazardLevelLabel(ctx, line.level)} · ${line.score}",
                    ),
                )
            }
            val unavailableTypes = state.hazardLines.filterNot { it.available }
            if (unavailableTypes.isNotEmpty()) {
                addView(V2Ui.spacer(activity, 4))
                addView(
                    V2Ui.styledSecondaryText(activity, ctx.l("hazards.unavailable_count")
                        .replace("%d", unavailableTypes.size.toString())).apply { textSize = 12f },
                )
            }
            if (overall.equals("unavailable", ignoreCase = true) && state.hazardLines.none { it.available }) {
                addView(V2Ui.styledSecondaryText(activity, unavailable))
            }
        }
    }

    private fun familyRiskCard(ctx: RenderContext, state: DashboardState): View? {
        if (state.familyRiskLines.isEmpty()) return null
        val activity = ctx.activity
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.family.title")).apply { textSize = 16f })
            state.familyHighestRisk?.let { highest ->
                addView(
                    V2Ui.styledSecondaryText(
                        activity,
                        "${ctx.l("dashboard.family.highest")} ${hazardLevelLabel(ctx, highest)}",
                    ).apply { textSize = 12f },
                )
            }
            addView(V2Ui.spacer(activity, 4))
            state.familyRiskLines.forEach { member ->
                val name = member.label?.takeIf { it.isNotBlank() } ?: member.relation
                val risk = FamilyRiskParser.riskLabel(member, ctx.rootShell.settingsViewModel.state.preferredLanguage)
                addView(V2Ui.styledSecondaryText(activity, "$name · $risk").apply { textSize = 13f })
            }
        }
    }

    private fun protectedDayCard(ctx: RenderContext, state: DashboardState): View? {
        if (!DashboardViewModel.isElevatedRisk(state.riskLevel)) return null
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val settings = rootShell.settingsViewModel.state
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.protected.title")).apply { textSize = 16f })
            addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.protected.subtitle")).apply { textSize = 12f })
            if (!state.exposureReducedMarked) {
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("dashboard.protected.exposure")).apply {
                        setOnClickListener {
                            Thread {
                                val profileId = rootShell.settingsViewModel.ensureProfile()
                                    ?: rootShell.symptomLogViewModel.state.profileId
                                if (!profileId.isNullOrBlank()) {
                                    rootShell.dashboardViewModel.markExposureReduced(
                                        userId = settings.userId,
                                        accessToken = settings.accessToken.ifBlank { null },
                                        profileId = profileId,
                                        preferredLanguage = settings.preferredLanguage,
                                    )
                                }
                                activity.runOnUiThread { ctx.rerender() }
                            }.start()
                        }
                    },
                )
            }
            if (state.safeWindows.isNotEmpty() && !state.highRiskAvoidedMarked) {
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("dashboard.protected.risk_avoided")).apply {
                        setOnClickListener {
                            Thread {
                                val profileId = rootShell.settingsViewModel.ensureProfile()
                                    ?: rootShell.symptomLogViewModel.state.profileId
                                if (!profileId.isNullOrBlank()) {
                                    rootShell.dashboardViewModel.markHighRiskAvoided(
                                        userId = settings.userId,
                                        accessToken = settings.accessToken.ifBlank { null },
                                        profileId = profileId,
                                        preferredLanguage = settings.preferredLanguage,
                                    )
                                }
                                activity.runOnUiThread { ctx.rerender() }
                            }.start()
                        }
                    },
                )
            }
            if (state.protectedDayStatus.isNotBlank()) {
                addView(V2Ui.styledSecondaryText(activity, state.protectedDayStatus))
            }
        }
    }

    private fun hazardTypeLabel(ctx: RenderContext, hazard: String): String {
        val key = when (hazard.lowercase()) {
            "heat" -> "hazards.type.heat"
            "air" -> "hazards.type.air"
            "uv" -> "hazards.type.uv"
            "pollen" -> "hazards.type.pollen"
            "smoke" -> "hazards.type.smoke"
            "dust" -> "hazards.type.dust"
            else -> null
        }
        return key?.let { ctx.l(it) } ?: hazard
    }

    private fun hazardLevelLabel(ctx: RenderContext, level: String): String {
        val key = when (level.lowercase()) {
            "low" -> "hazards.level.low"
            "moderate", "medium" -> "hazards.level.moderate"
            "high" -> "hazards.level.high"
            "very_high", "very high" -> "hazards.level.very_high"
            "unavailable" -> "hazards.level.unavailable"
            else -> null
        }
        return key?.let { ctx.l(it) } ?: level
    }

    private fun airMetricsCard(ctx: RenderContext, state: DashboardState): View? {
        val activity = ctx.activity
        val unavailable = ctx.l("dashboard.metric.unavailable")
        val rows = mutableListOf<Pair<String, String>>()
        rows.add(ctx.l("dashboard.metric_aqi") to (state.aqi?.toString() ?: unavailable))
        rows.add(
            ctx.l("dashboard.metric_pm25") to (state.pm25?.let { "${round1(it)} µg/m³" } ?: unavailable)
        )
        rows.add(
            ctx.l("dashboard.metric_ozone") to (state.ozone?.let { "${round1(it)} µg/m³" } ?: unavailable)
        )
        state.temperatureC?.let { rows.add(ctx.l("dashboard.metric_temp") to "${round1(it)}°C") }
        state.feelsLikeC?.let { rows.add(ctx.l("dashboard.metric_feels") to "${round1(it)}°C") }
        state.humidityPercent?.let { rows.add(ctx.l("dashboard.metric_humidity") to "${round1(it)}%") }
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.air_title")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            rows.forEach { (label, value) -> addView(metricRow(ctx, label, value)) }
        }
    }

    private fun metricRow(ctx: RenderContext, label: String, value: String): View {
        val activity = ctx.activity
        return LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = V2Ui.dp(activity, 2) }
            addView(
                V2Ui.styledSecondaryText(activity, label).apply {
                    textSize = 13f
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }
            )
            addView(
                V2Ui.styledBodyText(activity, value).apply {
                    textSize = 13f
                    setTextColor(Tokens.Text.primary)
                }
            )
        }
    }

    private fun wearableCard(ctx: RenderContext, state: DashboardState): View {
        val activity = ctx.activity
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("wearable.dashboard.title")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            if (state.wearableConnected && state.wearableSteps != null) {
                addView(V2Ui.styledSecondaryText(activity, "${ctx.l("wearable.dashboard.steps")}: ${state.wearableSteps}"))
                state.wearableLoadLevel?.let {
                    addView(
                        V2Ui.styledSecondaryText(
                            activity,
                            "${ctx.l("wearable.dashboard.load_risk")}: ${wearableLoadLabel(ctx, it)}",
                        ),
                    )
                }
                state.wearableSummary?.let {
                    addView(V2Ui.styledSecondaryText(activity, it))
                }
            } else {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("wearable.dashboard.not_connected")))
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("wearable.consent.connect")).apply {
                        setOnClickListener {
                            val host = activity as? WearableHealthHost
                            host?.requestWearableConnect {
                                host.syncWearablesIfPermitted()
                                ctx.rootShell.dashboardViewModel.markLoading()
                                ctx.rerender()
                                triggerLoad(ctx, isRetry = false)
                            }
                        }
                    }
                )
            }
        }
    }

    private fun actionsCard(ctx: RenderContext, state: DashboardState): View {
        val activity = ctx.activity
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.do_now")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            if (state.actions.isEmpty()) {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.no_actions")))
            } else {
                state.actions.forEach { action -> addView(actionTile(activity, "• $action")) }
            }
        }
    }

    private fun safeWindowsCard(ctx: RenderContext, state: DashboardState): View {
        val activity = ctx.activity
        return V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
            if (state.safeWindows.isEmpty()) {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.no_safe_windows")))
            } else {
                state.safeWindows.forEach { window -> addView(safePill(activity, window)) }
            }
        }
    }

    private fun actionTile(activity: android.app.Activity, text: String): TextView {
        return V2Ui.styledSecondaryText(activity, text).apply {
            textSize = 13f
            setTextColor(Tokens.Text.primary)
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 8), V2Ui.dp(activity, 10), V2Ui.dp(activity, 8))
            background = HiAirComponents.tileBackground(activity)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = V2Ui.dp(activity, 4) }
        }
    }

    private fun safePill(activity: android.app.Activity, text: String): TextView {
        return TextView(activity).apply {
            this.text = text
            textSize = 12f
            setTextColor(Tokens.Text.primary)
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 6), V2Ui.dp(activity, 10), V2Ui.dp(activity, 6))
            background = HiAirComponents.chipBackground(activity)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = V2Ui.dp(activity, 6) }
        }
    }

    private fun round1(value: Double): String {
        return String.format(Locale.US, "%.1f", value)
    }

    private fun moodLabel(ctx: RenderContext, riskLevel: String): String {
        return when (riskLevel.lowercase()) {
            "low" -> ctx.l("dashboard.mood.calm")
            "medium", "moderate" -> ctx.l("dashboard.mood.aware")
            "high" -> ctx.l("dashboard.mood.cautious")
            "very_high", "very high" -> ctx.l("dashboard.mood.protective")
            else -> ctx.l("dashboard.mood.calm")
        }
    }

    private fun wearableLoadLabel(ctx: RenderContext, level: String): String {
        return when (level.lowercase(Locale.ROOT)) {
            "low" -> ctx.l("wearable.load.low")
            "moderate" -> ctx.l("wearable.load.moderate")
            "elevated", "high" -> ctx.l("wearable.load.elevated")
            else -> ctx.l("wearable.load.none")
        }
    }
}
