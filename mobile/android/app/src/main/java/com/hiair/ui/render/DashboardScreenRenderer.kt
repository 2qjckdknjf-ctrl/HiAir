package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.design.Tokens
import com.hiair.ui.dailyActionsText
import com.hiair.ui.theme.V2Ui

internal object DashboardScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer

        val topRow = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(TextView(activity).apply {
                text = "📍 ${ctx.l("dashboard.location")}"
                textSize = 12f
                setTextColor(Tokens.Text.primary)
                setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 6), V2Ui.dp(activity, 10), V2Ui.dp(activity, 6))
                background = V2Ui.cardBackground(activity, "#1B3358", "#325888", 999)
            })
            addView(TextView(activity).apply {
                text = " • ${ctx.l("dashboard.freshness_fresh")}"
                textSize = 12f
                setTextColor(Tokens.Text.tertiary)
                setPadding(V2Ui.dp(activity, 8), 0, 0, 0)
            })
            addView(View(activity).apply {
                layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
            })
            addView(TextView(activity).apply {
                text = "◉"
                textSize = 18f
                setTextColor(Tokens.Text.primary)
            })
        }
        bodyContainer.addView(topRow)

        titleView.text = ctx.l("dashboard.greeting")
        val subtitle = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.improving")).apply {
            textSize = 14f
        }
        bodyContainer.addView(subtitle)

        val riskLabel = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.current_risk_title")).apply {
            textSize = 12f
        }
        val badge = TextView(activity).apply {
            text = ctx.l("dashboard.badge_moderate")
            textSize = 10f
            setTextColor(Tokens.RiskAccent.moderate)
            background = V2Ui.cardBackground(activity, "#3A2F17", strokeHex = "#6A5830", radiusDp = 10)
            setPadding(V2Ui.dp(activity, 8), V2Ui.dp(activity, 3), V2Ui.dp(activity, 8), V2Ui.dp(activity, 3))
        }
        val riskValue = V2Ui.styledBodyText(activity, "58").apply {
            textSize = 64f
        }
        val riskDetail = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.reason_code")).apply {
            textSize = 13f
        }
        val weatherTitle = V2Ui.styledBodyText(activity, "Sunny 26C")
        val weatherMood = V2Ui.styledSecondaryText(activity, globeMoodLabel(ctx.rootShell.dashboardViewModel.state.riskLevel))

        val weatherOrb = View(activity).apply {
            layoutParams = LinearLayout.LayoutParams(V2Ui.dp(activity, 64), V2Ui.dp(activity, 64))
        }
        V2Ui.startRiskGlobeAnimation(activity, weatherOrb) { rootShell.dashboardViewModel.state.riskLevel }

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
                        V2Ui.dp(activity, 3)
                    ).apply { topMargin = V2Ui.dp(activity, 8) }
                    background = V2Ui.cardBackground(activity, "#5378C8", strokeHex = "#5378C8", radiusDp = 12)
                })
            })
        }

        val dashboardCard = V2Ui.cardContainer(activity)
        val particles = AtmosphericParticlesView(activity).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                V2Ui.dp(activity, 56)
            )
            setPm25(pm25Estimate(ctx.rootShell.dashboardViewModel.state.riskLevel))
            setTintColor(Tokens.RiskAccent.forLevel(ctx.rootShell.dashboardViewModel.state.riskLevel))
        }
        dashboardCard.addView(particles)
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
        dashboardCard.addView(View(activity).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                V2Ui.dp(activity, 8)
            )
            background = V2Ui.cardBackground(activity, "#2A4A79", strokeHex = "#2A4A79", radiusDp = 12)
        })
        dashboardCard.addView(V2Ui.spacer(activity, 8))
        bodyContainer.addView(dashboardCard)
        bodyContainer.addView(V2Ui.cardContainer(activity).apply {
            addView(weatherRow)
        })

        val actionText = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.actions"))
        val actionsCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.do_now")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            addView(actionTile(activity, "💧 ${ctx.l("dashboard.action_1")}"))
            addView(actionTile(activity, "🫗 ${ctx.l("dashboard.action_2")}"))
            addView(actionTile(activity, "🚶 ${ctx.l("dashboard.action_3")}"))
            addView(V2Ui.spacer(activity, 6))
            addView(actionText)
        }
        bodyContainer.addView(actionsCard)

        val safeCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
            addView(safePill(activity, "06:00-08:00"))
            addView(safePill(activity, "16:30-19:00"))
            addView(safePill(activity, "22:00-23:00"))
        }
        bodyContainer.addView(safeCard)
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.tomorrow_hint")))

        val refreshButton = V2Ui.primaryButton(activity, ctx.l("dashboard.recompute")).apply {
            setOnClickListener {
                riskDetail.text = ctx.l("common.loading")
                Thread {
                    val settings = rootShell.settingsViewModel.state
                    val profileId = rootShell.symptomLogViewModel.state.profileId.ifBlank { null }
                    rootShell.dashboardViewModel.refresh(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId
                    )
                    val state = rootShell.dashboardViewModel.state
                    activity.runOnUiThread {
                        riskLabel.text = ctx.l("dashboard.current_risk_title")
                        riskValue.text = riskScore(state.riskLevel).toString()
                        badge.text = state.riskLevel.uppercase()
                        badge.setTextColor(Tokens.RiskAccent.forLevel(state.riskLevel))
                        weatherMood.text = globeMoodLabel(state.riskLevel)
                        particles.setPm25(pm25Estimate(state.riskLevel))
                        particles.setTintColor(Tokens.RiskAccent.forLevel(state.riskLevel))
                        riskDetail.text = "${state.headline}\n${state.explanation}"
                        safeCard.removeAllViews()
                        safeCard.addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
                        safeCard.addView(safePill(activity, state.nearestSafeWindow))
                        safeCard.addView(safePill(activity, "16:30-19:00"))
                        safeCard.addView(safePill(activity, "22:00-23:00"))
                        actionText.text = state.dailyActionsText()
                    }
                }.start()
            }
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

    private fun actionTile(activity: android.app.Activity, text: String): TextView {
        return V2Ui.styledSecondaryText(activity, text).apply {
            textSize = 13f
            setTextColor(Tokens.Text.primary)
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 8), V2Ui.dp(activity, 10), V2Ui.dp(activity, 8))
            background = V2Ui.cardBackground(activity, "#20385D", "#355987", 12)
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
            background = V2Ui.cardBackground(activity, "#1C355A", "#325888", 999)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = V2Ui.dp(activity, 6) }
        }
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

    private fun pm25Estimate(riskLevel: String): Double {
        return when (riskLevel.lowercase()) {
            "low" -> 12.0
            "medium", "moderate" -> 32.0
            "high" -> 52.0
            "very_high", "very high" -> 85.0
            else -> 25.0
        }
    }

    private fun globeMoodLabel(riskLevel: String): String {
        val mood = when (riskLevel.lowercase()) {
            "low" -> "Calm"
            "medium", "moderate" -> "Aware"
            "high" -> "Cautious"
            "very_high", "very high" -> "Protective"
            else -> "Calm"
        }
        return "Mood: $mood"
    }
}
