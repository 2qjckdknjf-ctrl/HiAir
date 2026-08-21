package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.Spinner
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.Tokens
import com.hiair.ui.planner.DailyPlannerViewModel
import com.hiair.ui.theme.V2Ui

internal object PlannerScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        bodyContainer.addView(HiAirComponents.brandHeader(activity))
        titleView.text = ctx.l("title.planner")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.subtitle")).apply { textSize = 13f })

        if (rootShell.settingsViewModel.state.isPremium) {
            bodyContainer.addView(
                V2Ui.styledBodyText(activity, ctx.l("settings.premium_active")).apply {
                    setTextColor(Tokens.Cta.start)
                }
            )
        } else {
            bodyContainer.addView(
                HiAirComponents.secondaryButton(activity, ctx.l("settings.upgrade_premium")).apply {
                    setOnClickListener {
                        rootShell.settingsViewModel.requestShowPaywall()
                        ctx.rerender()
                    }
                }
            )
        }

        val plannerState = rootShell.plannerViewModel.state
        val stateText = V2Ui.styledSecondaryText(
            activity,
            listOf(plannerState.statusText, plannerState.freshnessText)
                .filter { it.isNotBlank() }
                .joinToString("\n")
                .ifBlank { ctx.l("planner.fetch") },
        )
        val plannerCard = HiAirComponents.cardContainer(activity)
        plannerCard.addView(V2Ui.styledBodyText(activity, ctx.l("planner.summary")))
        val heatStrip = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
        }
        val keyEvents = V2Ui.styledSecondaryText(activity, buildKeyEvents(ctx, plannerState))
        plannerCard.addView(stateText)
        plannerCard.addView(V2Ui.spacer(activity, 6))
        plannerCard.addView(heatStrip)
        plannerCard.addView(V2Ui.spacer(activity, 8))
        plannerCard.addView(keyEvents)
        bodyContainer.addView(plannerCard)

        if (plannerState.premiumRequired) {
            bodyContainer.addView(
                HiAirComponents.cardContainer(activity).apply {
                    addView(
                        V2Ui.styledBodyText(activity, ctx.l("planner.premium_locked.title")).apply {
                            textSize = 16f
                        }
                    )
                    addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.premium_required")))
                    addView(
                        HiAirComponents.primaryButton(activity, ctx.l("insights.premium_locked.cta")).apply {
                            setOnClickListener {
                                rootShell.settingsViewModel.requestShowPaywall()
                                ctx.rerender()
                            }
                        }
                    )
                }
            )
        }

        if (plannerState.forecastAvailable && plannerState.hourly.isNotEmpty()) {
            renderHeatStrip(activity, heatStrip, plannerState.hourly)
        }

        fun loadPlanner() {
            stateText.text = ctx.l("common.loading")
            Thread {
                val resolvedProfileId = rootShell.settingsViewModel.ensureProfile()
                val settings = rootShell.settingsViewModel.state
                val profileId = resolvedProfileId
                    ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
                if (profileId.isBlank()) {
                    activity.runOnUiThread { stateText.text = ctx.l("planner.profile_required") }
                    return@Thread
                }
                rootShell.plannerViewModel.refresh(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                    profileId = profileId,
                    preferredLanguage = settings.preferredLanguage,
                )
                activity.runOnUiThread {
                    ctx.rerender()
                }
            }.start()
        }

        bodyContainer.addView(
            HiAirComponents.primaryButton(activity, ctx.l("planner.refresh")).apply {
                setOnClickListener { loadPlanner() }
            }
        )
        bodyContainer.addView(HiAirComponents.secondaryButton(activity, ctx.l("planner.apply")).apply {
            setOnClickListener {
                rootShell.openDashboard()
                ctx.rerender()
            }
        })

        renderActivityPlanCard(ctx, bodyContainer)

        // Auto-load once per session when planner opens with no data yet.
        if (
            !rootShell.plannerViewModel.hasAttemptedAutoLoad &&
            !plannerState.loading &&
            plannerState.hourly.isEmpty() &&
            !plannerState.premiumRequired
        ) {
            rootShell.plannerViewModel.hasAttemptedAutoLoad = true
            loadPlanner()
        }
    }

    private fun renderActivityPlanCard(
        ctx: RenderContext,
        bodyContainer: LinearLayout,
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val plannerViewModel = rootShell.plannerViewModel
        val plannerState = plannerViewModel.state
        val settings = rootShell.settingsViewModel.state
        val catalog = plannerState.activityCatalog.ifEmpty {
            DailyPlannerViewModel.fallbackActivityCatalogForUi()
        }
        val activityIds = catalog.map { it.id }
        val activityLabels = DailyPlannerViewModel.activityDisplayLabels(catalog, settings.preferredLanguage)
        val selectedIndex = activityIds.indexOf(plannerState.selectedActivityId).coerceAtLeast(0)

        val statusView = V2Ui.styledSecondaryText(
            activity,
            plannerState.activityPlanStatusText.ifBlank { ctx.l("planner.activity.hint") },
        )
        val windowsView = V2Ui.styledBodyText(activity, buildActivityWindowText(ctx, plannerState))
        val recommendedView = V2Ui.styledSecondaryText(activity, "")

        val activityCard = HiAirComponents.cardContainer(activity).apply {
            addView(
                V2Ui.styledBodyText(activity, ctx.l("planner.activity.title")).apply {
                    textSize = 16f
                }
            )
            addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.activity.subtitle")).apply { textSize = 13f })
            addView(V2Ui.spacer(activity, 8))
            val spinner = Spinner(activity).apply {
                adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, activityLabels)
                onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(
                        parent: AdapterView<*>?,
                        view: View?,
                        position: Int,
                        id: Long,
                    ) {
                        val nextActivityId = activityIds.getOrNull(position) ?: return
                        if (nextActivityId == plannerViewModel.state.selectedActivityId) return
                        plannerViewModel.selectActivity(nextActivityId)
                        plannerViewModel.hasAttemptedActivityPlanLoad = false
                        loadActivityPlan(ctx)
                    }

                    override fun onNothingSelected(parent: AdapterView<*>?) = Unit
                }
                setSelection(selectedIndex.coerceIn(0, activityLabels.lastIndex.coerceAtLeast(0)), false)
            }
            addView(spinner)
            addView(V2Ui.spacer(activity, 8))
            addView(statusView)
            addView(V2Ui.spacer(activity, 6))
            addView(windowsView)
            addView(recommendedView)
            if (plannerState.activityPremiumRequired) {
                addView(V2Ui.spacer(activity, 8))
                addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.activity.premium_required")))
                addView(
                    HiAirComponents.primaryButton(activity, ctx.l("insights.premium_locked.cta")).apply {
                        setOnClickListener {
                            rootShell.settingsViewModel.requestShowPaywall()
                            ctx.rerender()
                        }
                    }
                )
            } else {
                addView(V2Ui.spacer(activity, 8))
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("planner.activity.refresh")).apply {
                        setOnClickListener {
                            plannerViewModel.hasAttemptedActivityPlanLoad = false
                            loadActivityPlan(ctx)
                        }
                    }
                )
            }
        }
        bodyContainer.addView(activityCard)

        if (plannerState.activityRecommendedStart.isNotBlank()) {
            recommendedView.text = ctx.l("planner.activity.recommended")
                .replaceFirst("%@", plannerState.activityRecommendedStart)
        }

        if (
            !plannerViewModel.hasAttemptedActivityCatalogLoad &&
            !settings.userId.isBlank()
        ) {
            plannerViewModel.hasAttemptedActivityCatalogLoad = true
            Thread {
                plannerViewModel.loadActivityCatalog(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                )
                activity.runOnUiThread {
                    plannerViewModel.hasAttemptedActivityPlanLoad = false
                    loadActivityPlan(ctx)
                    ctx.rerender()
                }
            }.start()
        } else if (
            !plannerViewModel.hasAttemptedActivityPlanLoad &&
            !plannerState.activityPlanLoading &&
            !plannerState.activityPremiumRequired &&
            !settings.userId.isBlank()
        ) {
            plannerViewModel.hasAttemptedActivityPlanLoad = true
            loadActivityPlan(ctx)
        }
    }

    private fun loadActivityPlan(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val settings = rootShell.settingsViewModel.state
        Thread {
            val resolvedProfileId = rootShell.settingsViewModel.ensureProfile()
            val profileId = resolvedProfileId
                ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
            if (profileId.isBlank()) {
                activity.runOnUiThread { ctx.rerender() }
                return@Thread
            }
            rootShell.plannerViewModel.refreshActivityPlan(
                userId = settings.userId,
                accessToken = settings.accessToken.ifBlank { null },
                profileId = profileId,
                preferredLanguage = settings.preferredLanguage,
            )
            activity.runOnUiThread { ctx.rerender() }
        }.start()
    }

    private fun buildActivityWindowText(
        ctx: RenderContext,
        state: com.hiair.ui.planner.PlannerState,
    ): String {
        if (state.activityPlanLoading) {
            return ctx.l("common.loading")
        }
        if (!state.activityForecastAvailable && state.activityPlanStatusText.isNotBlank()) {
            return "• ${state.activityPlanStatusText}"
        }
        if (state.activityWindows.isEmpty()) {
            return "• ${state.activityPlanStatusText.ifBlank { ctx.l("planner.activity.hint") }}"
        }
        return state.activityWindows.joinToString("\n") { "• ${it.line}" }
    }

    private fun renderHeatStrip(activity: android.app.Activity, container: LinearLayout, hourly: List<String>) {
        container.removeAllViews()
        val items = hourly.take(24)
        items.forEachIndexed { index, item ->
            val risk = item.substringAfter(":", "moderate").trim()
            container.addView(View(activity).apply {
                layoutParams = LinearLayout.LayoutParams(
                    V2Ui.dp(activity, 4),
                    V2Ui.dp(activity, if (index % 2 == 0) 30 else 22)
                ).apply {
                    rightMargin = V2Ui.dp(activity, 2)
                }
                background = V2Ui.cardBackground(
                    activity,
                    fillHex = colorHex(risk),
                    strokeHex = colorHex(risk),
                    radiusDp = 2
                )
            })
        }
    }

    private fun buildKeyEvents(ctx: RenderContext, state: com.hiair.ui.planner.PlannerState): String {
        if (!state.forecastAvailable) {
            return "• ${state.statusText.ifBlank { ctx.l("planner.forecast_unavailable") }}"
        }
        val lines = mutableListOf<String>()
        if (state.peakLine.isNotBlank()) {
            lines.add("• ${state.peakLine}")
        }
        val firstSafe = state.safeWindows.firstOrNull()
        if (firstSafe != null) {
            lines.add("• $firstSafe")
        }
        val firstVent = state.ventilationWindows.firstOrNull()
        if (firstVent != null) {
            lines.add("• ${ctx.l("planner.window.ventilation")}: $firstVent")
        }
        return lines.joinToString("\n").ifBlank { "• ${ctx.l("planner.fetch")}" }
    }

    private fun colorHex(risk: String): String = HiAirComponents.riskAccentHex(risk)
}
