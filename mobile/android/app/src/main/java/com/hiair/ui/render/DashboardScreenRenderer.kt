package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.health.WearableHealthHost
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.Tokens
import com.hiair.ui.dailyActionsText
import com.hiair.ui.theme.V2Ui

internal object DashboardScreenRenderer {
    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        (activity as? WearableHealthHost)?.syncWearablesIfPermitted()
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
                background = HiAirComponents.chipBackground(activity)
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
        bodyContainer.addView(
            HiAirComponents.brandHeader(
                activity,
                compact = true,
                showOrb = true,
                orbSizeDp = 44,
            )
        )

        val initialRisk = ctx.rootShell.dashboardViewModel.state.riskLevel
        val riskGauge = HiAirComponents.riskGaugeView(
            activity,
            riskScore(initialRisk),
            moodLabel(ctx, initialRisk),
            initialRisk,
        )
        val riskDetail = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.reason_code")).apply {
            textSize = 13f
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val weatherTitle = V2Ui.styledBodyText(activity, ctx.l("dashboard.weather_title"))
        val weatherMood = V2Ui.styledSecondaryText(activity, globeMoodLabel(ctx, initialRisk))

        val weatherOrb = HiAirComponents.brandOrbView(activity, 64)

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
                    background = V2Ui.cardBackground(
                        activity,
                        HiAirComponents.colorHex(Tokens.Surface.weatherBar),
                        strokeHex = HiAirComponents.colorHex(Tokens.Surface.weatherBar),
                        radiusDp = 12
                    )
                })
            })
        }

        val dashboardCard = HiAirComponents.cardContainer(activity).apply {
            addView(
                HiAirComponents.sectionTitle(activity, ctx.l("dashboard.current_risk_title"))
            )
            addView(riskGauge)
            addView(riskDetail)
        }
        bodyContainer.addView(dashboardCard)

        val wearableState = ctx.rootShell.dashboardViewModel.state
        val wearableCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("wearable.dashboard.title")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            if (wearableState.wearableConnected && wearableState.wearableSteps != null) {
                addView(V2Ui.styledSecondaryText(activity, "${ctx.l("wearable.dashboard.steps")}: ${wearableState.wearableSteps}"))
                addView(V2Ui.styledSecondaryText(activity, "${ctx.l("wearable.dashboard.load_risk")}: ${wearableState.wearableLoadLevel}"))
                if (wearableState.wearableSummary.isNotBlank() && wearableState.wearableSummary != "-") {
                    addView(V2Ui.styledSecondaryText(activity, wearableState.wearableSummary))
                }
            } else {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("wearable.dashboard.not_connected")))
                addView(HiAirComponents.secondaryButton(activity, ctx.l("wearable.consent.connect")).apply {
                    setOnClickListener {
                        val host = activity as? WearableHealthHost
                        host?.requestWearableConnect {
                            val settings = ctx.rootShell.settingsViewModel.state
                            val profileId = ctx.rootShell.symptomLogViewModel.state.profileId.ifBlank { null }
                            host.syncWearablesIfPermitted()
                            Thread {
                                ctx.rootShell.dashboardViewModel.refresh(
                                    userId = settings.userId,
                                    accessToken = settings.accessToken.ifBlank { null },
                                    profileId = profileId,
                                )
                                activity.runOnUiThread { ctx.rerender() }
                            }.start()
                        }
                    }
                })
            }
        }
        bodyContainer.addView(wearableCard)

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

        val refreshButton = HiAirComponents.primaryButton(activity, ctx.l("dashboard.recompute")).apply {
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
                        riskGauge.bind(
                            riskScore(state.riskLevel),
                            moodLabel(ctx, state.riskLevel),
                            state.riskLevel,
                        )
                        weatherMood.text = globeMoodLabel(ctx, state.riskLevel)
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

        val logSymptomsButton = HiAirComponents.secondaryButton(activity, ctx.l("dashboard.log_symptoms")).apply {
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

    private fun riskScore(riskLevel: String): Int {
        return when (riskLevel.lowercase()) {
            "low" -> 24
            "medium", "moderate" -> 58
            "high" -> 79
            "very_high", "very high" -> 90
            else -> 58
        }
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

    private fun globeMoodLabel(ctx: RenderContext, riskLevel: String): String {
        return "${ctx.l("dashboard.mood_prefix")}: ${moodLabel(ctx, riskLevel)}"
    }
}
