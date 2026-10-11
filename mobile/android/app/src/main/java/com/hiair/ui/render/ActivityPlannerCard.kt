package com.hiair.ui.render

import android.content.Intent
import android.provider.CalendarContract
import java.time.OffsetDateTime
import com.hiair.analytics.ProductAnalytics
import com.hiair.ui.planner.ActionTimePreference
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

internal object ActivityPlannerCard {
    fun render(
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
        val durationOptions = DailyPlannerViewModel.durationOptionsForUi()
        val durationLabels = durationOptions.map { "$it min" }
        val durationSelectedIndex = durationOptions.indexOf(plannerState.selectedDurationMinutes).coerceAtLeast(0)
        val intensityOptions = DailyPlannerViewModel.intensityOptionsForUi()
        val intensityLabels = intensityOptions.map { localizedIntensity(ctx, it) }
        val intensitySelectedIndex = intensityOptions.indexOf(plannerState.selectedIntensity).coerceAtLeast(0)

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
                    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
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
            addView(V2Ui.styledSecondaryText(activity, ctx.l("health.metric.workout_duration")).apply { textSize = 13f })
            val durationSpinner = Spinner(activity).apply {
                adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, durationLabels)
                onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                        val nextDuration = durationOptions.getOrNull(position) ?: return
                        if (nextDuration == plannerViewModel.state.selectedDurationMinutes) return
                        plannerViewModel.selectDurationMinutes(nextDuration)
                        plannerViewModel.hasAttemptedActivityPlanLoad = false
                        loadActivityPlan(ctx)
                    }

                    override fun onNothingSelected(parent: AdapterView<*>?) = Unit
                }
                setSelection(durationSelectedIndex.coerceIn(0, durationLabels.lastIndex.coerceAtLeast(0)), false)
            }
            addView(durationSpinner)

            addView(V2Ui.spacer(activity, 8))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("settings.work.workload")).apply { textSize = 13f })
            val intensitySpinner = Spinner(activity).apply {
                adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, intensityLabels)
                onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                        val nextIntensity = intensityOptions.getOrNull(position) ?: return
                        if (nextIntensity == plannerViewModel.state.selectedIntensity) return
                        plannerViewModel.selectIntensity(nextIntensity)
                        plannerViewModel.hasAttemptedActivityPlanLoad = false
                        loadActivityPlan(ctx)
                    }

                    override fun onNothingSelected(parent: AdapterView<*>?) = Unit
                }
                setSelection(intensitySelectedIndex.coerceIn(0, intensityLabels.lastIndex.coerceAtLeast(0)), false)
            }
            addView(intensitySpinner)

            if (plannerState.savedPlaces.isNotEmpty()) {
                addView(V2Ui.spacer(activity, 8))
                val placeIds = listOf("") + plannerState.savedPlaces.map { it.id }
                val placeLabels = listOf(ctx.l("planner.activity.place_home")) + plannerState.savedPlaces.map { it.name }
                val placeSelectedIndex = placeIds.indexOf(plannerState.selectedPlaceId).coerceAtLeast(0)
                val placeSpinner = Spinner(activity).apply {
                    adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item, placeLabels)
                    onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                        override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                            val nextPlaceId = placeIds.getOrNull(position) ?: ""
                            if (nextPlaceId == plannerViewModel.state.selectedPlaceId) return
                            plannerViewModel.selectPlace(nextPlaceId)
                            plannerViewModel.hasAttemptedActivityPlanLoad = false
                            loadActivityPlan(ctx)
                        }

                        override fun onNothingSelected(parent: AdapterView<*>?) = Unit
                    }
                    setSelection(placeSelectedIndex.coerceIn(0, placeLabels.lastIndex.coerceAtLeast(0)), false)
                }
                addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.activity.place")).apply { textSize = 13f })
                addView(placeSpinner)
            }
            addView(V2Ui.spacer(activity, 8))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.activity.time")))
            addView(Spinner(activity).apply {
                val options = ActionTimePreference.values()
                adapter = ArrayAdapter(activity, android.R.layout.simple_spinner_dropdown_item,
                    options.map { ctx.l("planner.activity.time.${it.id}") })
                setSelection(options.indexOf(plannerState.selectedTimePreference), false)
                isEnabled = plannerState.activityTimezone.isNotBlank()
                contentDescription = ctx.l("planner.activity.time")
                onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                        if (options[position] == plannerViewModel.state.selectedTimePreference) return
                        plannerViewModel.selectTimePreference(options[position])
                        plannerViewModel.hasAttemptedActivityPlanLoad = false
                        loadActivityPlan(ctx)
                    }
                    override fun onNothingSelected(parent: AdapterView<*>?) = Unit
                }
            })
            addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.activity.resolution")))
            addView(statusView)
            addView(V2Ui.spacer(activity, 6))
            addView(windowsView)
            addView(recommendedView)
            val calendarStart = runCatching { OffsetDateTime.parse(plannerState.activityRecommendedStartRaw) }.getOrNull()
            if (calendarStart != null) {
                val calendarIntent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, "HiAir · " + activityLabels[selectedIndex])
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, calendarStart.toInstant().toEpochMilli())
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME,
                        calendarStart.plusMinutes(plannerState.selectedDurationMinutes.toLong()).toInstant().toEpochMilli())
                if (calendarIntent.resolveActivity(activity.packageManager) != null) {
                    addView(HiAirComponents.secondaryButton(activity, ctx.l("planner.activity.calendar")).apply {
                        setOnClickListener {
                            runCatching { activity.startActivity(calendarIntent) }
                                .onSuccess { ProductAnalytics.track("action_calendar_editor_opened", mapOf("platform" to "android")) }
                                .onFailure { statusView.text = ctx.l("common.unavailable") }
                        }
                    })
                }
            }
            if (plannerState.activityRecommendedStartRaw.isNotBlank()) {
                addView(V2Ui.spacer(activity, 6))
                addView(
                    HiAirComponents.secondaryButton(activity, "+30 min").apply {
                        setOnClickListener {
                            if (plannerViewModel.tryThirtyMinutesLater()) {
                                plannerViewModel.hasAttemptedActivityPlanLoad = false
                                loadActivityPlan(ctx)
                            }
                        }
                    }
                )
            }
            if (
                plannerState.activityForecastAvailable &&
                plannerState.activityWindows.isNotEmpty() &&
                !plannerState.activityPlanMarked &&
                plannerState.activityRecommendedStartRaw.isNotBlank()
            ) {
                addView(V2Ui.spacer(activity, 8))
                addView(
                    HiAirComponents.secondaryButton(activity, ctx.l("planner.activity.mark_planned")).apply {
                        setOnClickListener {
                            Thread {
                                val resolvedProfileId = rootShell.settingsViewModel.ensureProfile()
                                    ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
                                if (resolvedProfileId.isNotBlank()) {
                                    plannerViewModel.markActivityPlanned(
                                        userId = settings.userId,
                                        accessToken = settings.accessToken.ifBlank { null },
                                        profileId = resolvedProfileId,
                                        preferredLanguage = settings.preferredLanguage,
                                    )
                                }
                                activity.runOnUiThread { ctx.rerender() }
                            }.start()
                        }
                    }
                )
            }
            if (plannerState.activityPlanMarkStatus.isNotBlank()) {
                addView(V2Ui.spacer(activity, 6))
                addView(V2Ui.styledSecondaryText(activity, plannerState.activityPlanMarkStatus))
            }
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

        if (!plannerViewModel.hasAttemptedActivityCatalogLoad && settings.userId.isNotBlank()) {
            plannerViewModel.hasAttemptedActivityCatalogLoad = true
            Thread {
                plannerViewModel.loadActivityCatalog(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                )
                plannerViewModel.loadSavedPlaces(
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
            settings.userId.isNotBlank()
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
            val profileId = resolvedProfileId ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
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
        if (state.activityPlanLoading) return ctx.l("common.loading")
        if (!state.activityForecastAvailable && state.activityPlanStatusText.isNotBlank()) {
            return "• ${state.activityPlanStatusText}"
        }
        if (state.activityWindows.isEmpty()) {
            return "• ${state.activityPlanStatusText.ifBlank { ctx.l("planner.activity.hint") }}"
        }
        return state.activityWindows.joinToString("\n") { "• ${it.line}" }
    }

    private fun localizedIntensity(ctx: RenderContext, intensity: String): String {
        return when (intensity.lowercase()) {
            "low" -> ctx.l("hazards.level.low")
            "moderate" -> ctx.l("hazards.level.moderate")
            "high" -> ctx.l("hazards.level.high")
            else -> intensity
        }
    }

}
