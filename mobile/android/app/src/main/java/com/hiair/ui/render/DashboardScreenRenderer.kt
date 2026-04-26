package com.hiair.ui.render

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.dailyActionsText
import com.hiair.ui.theme.V2Ui

internal object DashboardScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("common.city_updated")).apply { textSize = 11f })
        titleView.text = ctx.l("dashboard.greeting")
        val subtitle = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.improving")).apply {
            textSize = 13f
        }
        bodyContainer.addView(subtitle)

        val riskLabel = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.current_risk_title")).apply {
            textSize = 12f
        }
        val currentState = rootShell.dashboardViewModel.state
        val badge = TextView(activity).apply {
            text = if (currentState.riskLevel == "-") ctx.l("dashboard.pending") else currentState.riskLevel.uppercase()
            textSize = 10f
            setTextColor(Color.parseColor("#FDD671"))
            background = V2Ui.cardBackground(activity, "#3A2F17", strokeHex = "#6A5830", radiusDp = 10)
            setPadding(V2Ui.dp(activity, 8), V2Ui.dp(activity, 3), V2Ui.dp(activity, 8), V2Ui.dp(activity, 3))
        }
        val riskValue = V2Ui.styledBodyText(activity, riskScore(currentState.riskLevel).toString()).apply {
            textSize = 42f
        }
        val riskDetail = V2Ui.styledSecondaryText(activity, currentState.explanation).apply {
            textSize = 12f
        }
        val weatherTitle = V2Ui.styledBodyText(activity, currentState.environmentSummary)
        val weatherMood = V2Ui.styledSecondaryText(activity, "${ctx.l("dashboard.source")}: ${currentState.dataSource}")

        val weatherOrb = View(activity).apply {
            layoutParams = LinearLayout.LayoutParams(V2Ui.dp(activity, 64), V2Ui.dp(activity, 64))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(Color.parseColor("#52E0B0"), Color.parseColor("#64B8FF"))
                gradientType = GradientDrawable.RADIAL_GRADIENT
                gradientRadius = V2Ui.dp(activity, 48).toFloat()
            }
        }
        val weatherRow = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(weatherOrb)
            addView(LinearLayout(activity).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    leftMargin = V2Ui.dp(activity, 12)
                    weight = 1f
                }
                addView(weatherTitle)
                addView(weatherMood)
                addView(View(activity).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        V2Ui.dp(activity, 4)
                    ).apply { topMargin = V2Ui.dp(activity, 8) }
                    background = V2Ui.cardBackground(activity, "#5378C8", strokeHex = "#5378C8", radiusDp = 12)
                })
            })
        }

        val dashboardCard = V2Ui.cardContainer(activity)
        dashboardCard.addView(LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(riskLabel)
            addView(View(activity).apply {
                layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
            })
            addView(badge)
        })
        dashboardCard.addView(riskValue)
        dashboardCard.addView(riskDetail)
        dashboardCard.addView(V2Ui.spacer(activity, 8))
        dashboardCard.addView(weatherRow)
        bodyContainer.addView(dashboardCard)

        val actionText = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.actions"))
        val actionsCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.do_now")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            addView(V2Ui.styledSecondaryText(activity, "• ${ctx.l("dashboard.action_1")}"))
            addView(V2Ui.styledSecondaryText(activity, "• ${ctx.l("dashboard.action_2")}"))
            addView(V2Ui.styledSecondaryText(activity, "• ${ctx.l("dashboard.action_3")}"))
            addView(V2Ui.spacer(activity, 6))
            addView(actionText)
        }
        bodyContainer.addView(actionsCard)

        val safeWindowsText = V2Ui.styledSecondaryText(activity, "• ${currentState.nearestSafeWindow}")
        val safeCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
            addView(safeWindowsText)
        }
        bodyContainer.addView(safeCard)

        fun refreshDashboard() {
            riskDetail.text = ctx.l("common.loading")
            Thread {
                val settings = rootShell.settingsViewModel.state
                val profileId = settings.profileId.ifBlank {
                    rootShell.symptomLogViewModel.state.profileId
                }.ifBlank { null }
                rootShell.dashboardViewModel.refresh(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                    profileId = profileId,
                    language = settings.preferredLanguage
                )
                val state = rootShell.dashboardViewModel.state
                activity.runOnUiThread {
                    riskLabel.text = ctx.l("dashboard.current_risk_title")
                    riskValue.text = riskScore(state.riskLevel).toString()
                    badge.text = state.riskLevel.uppercase()
                    riskDetail.text = "${state.headline}\n${state.explanation}"
                    weatherTitle.text = state.environmentSummary
                    weatherMood.text = "${ctx.l("dashboard.source")}: ${state.dataSource}"
                    safeWindowsText.text = "• ${state.nearestSafeWindow}"
                    actionText.text = state.dailyActionsText(settings.preferredLanguage)
                }
            }
        }
        if (currentState.riskLevel == "-") {
            refreshDashboard()
        }
        val refreshButton = V2Ui.primaryButton(activity, ctx.l("dashboard.recompute")).apply {
            setOnClickListener { refreshDashboard() }
        }
        bodyContainer.addView(refreshButton)

        val logSymptomsButton = V2Ui.primaryButton(activity, ctx.l("dashboard.log_symptoms")).apply {
            setOnClickListener {
                rootShell.openSymptoms()
                ctx.rerender()
            }
        }
        bodyContainer.addView(logSymptomsButton)
    }

    private fun riskScore(riskLevel: String): Int {
        return when (riskLevel.lowercase()) {
            "low" -> 32
            "medium", "moderate" -> 58
            "high" -> 78
            "very_high", "very high" -> 91
            else -> 58
        }
    }
}
