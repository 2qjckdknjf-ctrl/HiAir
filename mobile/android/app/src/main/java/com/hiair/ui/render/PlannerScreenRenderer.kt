package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.Tokens
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

        val stateText = V2Ui.styledSecondaryText(activity, ctx.l("planner.fetch"))
        val plannerCard = HiAirComponents.cardContainer(activity)
        plannerCard.addView(V2Ui.styledBodyText(activity, ctx.l("planner.summary")))
        val heatStrip = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.BOTTOM
        }
        val keyEvents = V2Ui.styledSecondaryText(activity, "• ${ctx.l("planner.fetch")}")
        plannerCard.addView(stateText)
        plannerCard.addView(V2Ui.spacer(activity, 6))
        plannerCard.addView(heatStrip)
        plannerCard.addView(V2Ui.spacer(activity, 8))
        plannerCard.addView(keyEvents)
        bodyContainer.addView(plannerCard)

        val refreshButton = HiAirComponents.primaryButton(activity, ctx.l("planner.refresh")).apply {
            setOnClickListener {
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
                    val state = rootShell.plannerViewModel.state
                    activity.runOnUiThread {
                        stateText.text = state.statusText
                        if (state.premiumRequired) {
                            rootShell.settingsViewModel.requestShowPaywall()
                            ctx.rerender()
                            return@runOnUiThread
                        }
                        renderHeatStrip(activity, heatStrip, state.hourly)
                        keyEvents.text = buildKeyEvents(ctx, state)
                    }
                }.start()
            }
        }
        bodyContainer.addView(refreshButton)
        bodyContainer.addView(HiAirComponents.secondaryButton(activity, ctx.l("planner.apply")).apply {
            setOnClickListener {
                rootShell.openDashboard()
                ctx.rerender()
            }
        })
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
        val lines = mutableListOf<String>()
        if (state.peakLine.isNotBlank()) {
            lines.add("• ${state.peakLine}")
        }
        val firstSafe = state.safeWindows.firstOrNull()
        if (firstSafe != null) {
            lines.add("• ${ctx.l("dashboard.safe_windows")}: $firstSafe")
        }
        return lines.joinToString("\n").ifBlank { "• ${ctx.l("planner.fetch")}" }
    }

    private fun colorHex(risk: String): String = HiAirComponents.riskAccentHex(risk)
}
