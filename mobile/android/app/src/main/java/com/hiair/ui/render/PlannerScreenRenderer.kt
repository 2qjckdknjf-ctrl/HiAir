package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.Tokens
import com.hiair.ui.theme.V2Ui

internal object PlannerScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("title.planner")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("planner.subtitle")).apply { textSize = 13f })

        val stateText = V2Ui.styledSecondaryText(activity, ctx.l("planner.fetch"))
        val plannerCard = V2Ui.cardContainer(activity)
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

        val refreshButton = V2Ui.primaryButton(activity, ctx.l("planner.refresh")).apply {
            setOnClickListener {
                stateText.text = ctx.l("common.loading")
                Thread {
                    val settings = rootShell.settingsViewModel.state
                    val profileId = rootShell.symptomLogViewModel.state.profileId
                    if (profileId.isBlank()) {
                        activity.runOnUiThread { stateText.text = ctx.l("planner.profile_required") }
                        return@Thread
                    }
                    rootShell.plannerViewModel.refresh(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId
                    )
                    val state = rootShell.plannerViewModel.state
                    activity.runOnUiThread {
                        stateText.text = state.statusText
                        renderHeatStrip(activity, heatStrip, state.hourly)
                        keyEvents.text = buildKeyEvents(ctx, state.safeWindows, state.hourly)
                    }
                }.start()
            }
        }
        bodyContainer.addView(refreshButton)
        bodyContainer.addView(V2Ui.primaryButton(activity, ctx.l("planner.apply")).apply {
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

    private fun buildKeyEvents(ctx: RenderContext, safeWindows: List<String>, hourly: List<String>): String {
        val peak = hourly.maxByOrNull { riskWeight(it.substringAfter(":", "low")) } ?: "-"
        val firstSafe = safeWindows.firstOrNull() ?: "-"
        return "• Peak: $peak\n• ${ctx.l("dashboard.safe_windows")}: $firstSafe"
    }

    private fun colorHex(risk: String): String {
        return when (risk.lowercase()) {
            "low" -> String.format("#%08X", Tokens.RiskAccent.low)
            "moderate", "medium" -> String.format("#%08X", Tokens.RiskAccent.moderate)
            "high" -> String.format("#%08X", Tokens.RiskAccent.high)
            "very_high", "very high" -> String.format("#%08X", Tokens.RiskAccent.veryHigh)
            else -> String.format("#%08X", Tokens.Text.secondary)
        }
    }

    private fun riskWeight(risk: String): Int {
        return when (risk.lowercase()) {
            "low" -> 1
            "moderate", "medium" -> 2
            "high" -> 3
            "very_high", "very high" -> 4
            else -> 0
        }
    }
}
