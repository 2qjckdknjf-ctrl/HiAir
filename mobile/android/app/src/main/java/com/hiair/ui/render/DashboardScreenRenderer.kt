package com.hiair.ui.render

import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.DashboardLoadState
import com.hiair.ui.dailyActionsText
import com.hiair.ui.safeWindowsText
import com.hiair.ui.theme.V2Ui

internal object DashboardScreenRenderer {
    private var dashboardTracked = false

    fun render(ctx: RenderContext) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val titleView = ctx.titleView
        val bodyContainer = ctx.bodyContainer
        val lang = rootShell.settingsViewModel.state.preferredLanguage

        if (!dashboardTracked) {
            dashboardTracked = true
            ctx.analytics.track(
                com.hiair.analytics.AnalyticsEvents.DASHBOARD_OPENED,
                userId = ctx.session.userId.ifBlank { null },
                accessToken = ctx.session.accessToken.ifBlank { null }
            )
            ctx.analytics.track(
                com.hiair.analytics.AnalyticsEvents.MORNING_BRIEFING_OPENED,
                userId = ctx.session.userId.ifBlank { null },
                accessToken = ctx.session.accessToken.ifBlank { null }
            )
        }

        titleView.text = ctx.l("dashboard.greeting")
        bodyContainer.addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.subtitle")).apply { textSize = 13f })

        val state = rootShell.dashboardViewModel.state
        val briefingCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.morning_briefing")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            addView(V2Ui.styledSecondaryText(activity, briefingText(state, lang)).apply { textSize = 13f })
        }
        bodyContainer.addView(briefingCard)

        val riskLabel = V2Ui.styledSecondaryText(activity, ctx.l("dashboard.current_risk_title")).apply { textSize = 12f }
        val badge = TextView(activity).apply {
            textSize = 10f
            setTextColor(Color.parseColor("#FDD671"))
            background = V2Ui.cardBackground(activity, "#3A2F17", strokeHex = "#6A5830", radiusDp = 10)
            setPadding(V2Ui.dp(activity, 8), V2Ui.dp(activity, 3), V2Ui.dp(activity, 8), V2Ui.dp(activity, 3))
        }
        val riskValue = V2Ui.styledBodyText(activity, riskScoreText(state)).apply { textSize = 42f }
        val riskDetail = V2Ui.styledSecondaryText(activity, riskDetailText(state, lang)).apply { textSize = 12f }
        val envLine = V2Ui.styledSecondaryText(activity, envText(state, lang)).apply { textSize = 12f }

        val dashboardCard = V2Ui.cardContainer(activity)
        dashboardCard.addView(LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(riskLabel)
            addView(View(activity).apply { layoutParams = LinearLayout.LayoutParams(0, 1, 1f) })
            addView(badge)
        })
        dashboardCard.addView(riskValue)
        dashboardCard.addView(riskDetail)
        dashboardCard.addView(envLine)
        bodyContainer.addView(dashboardCard)

        if (state.breakdownLines.isNotEmpty()) {
            val breakdownCard = V2Ui.cardContainer(activity).apply {
                addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.risk_breakdown")).apply { textSize = 16f })
                addView(V2Ui.spacer(activity, 6))
                state.breakdownLines.forEach { line ->
                    addView(V2Ui.styledSecondaryText(activity, line))
                }
            }
            bodyContainer.addView(breakdownCard)
        }

        val actionText = V2Ui.styledSecondaryText(activity, state.dailyActionsText().ifBlank { ctx.l("dashboard.no_actions") })
        val actionsCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.do_now")).apply { textSize = 16f })
            addView(V2Ui.spacer(activity, 6))
            addView(actionText)
        }
        bodyContainer.addView(actionsCard)

        val safeWindowsText = V2Ui.styledSecondaryText(
            activity,
            state.safeWindowsText(ctx.l("dashboard.no_safe_window"))
        )
        val safeCard = V2Ui.cardContainer(activity).apply {
            addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
            addView(safeWindowsText)
        }
        bodyContainer.addView(safeCard)

        val refreshButton = V2Ui.primaryButton(activity, ctx.l("dashboard.recompute")).apply {
            setOnClickListener { loadDashboard(ctx, riskValue, badge, riskDetail, envLine, actionText, safeWindowsText) }
        }
        bodyContainer.addView(refreshButton)

        val shareButton = V2Ui.secondaryButton(activity, ctx.l("dashboard.share")).apply {
            setOnClickListener {
                ctx.analytics.track(
                    com.hiair.analytics.AnalyticsEvents.SHARE_CARD_CLICKED,
                    userId = ctx.session.userId.ifBlank { null },
                    accessToken = ctx.session.accessToken.ifBlank { null }
                )
                com.hiair.share.ShareHelper.shareDashboard(activity, rootShell, lang)
            }
        }
        bodyContainer.addView(shareButton)

        val logSymptomsButton = V2Ui.primaryButton(activity, ctx.l("dashboard.log_symptoms")).apply {
            setOnClickListener {
                rootShell.openSymptoms()
                ctx.rerender()
            }
        }
        bodyContainer.addView(logSymptomsButton)

        if (state.loadState == DashboardLoadState.IDLE) {
            loadDashboard(ctx, riskValue, badge, riskDetail, envLine, actionText, safeWindowsText)
        }
    }

    private fun loadDashboard(
        ctx: RenderContext,
        riskValue: TextView,
        badge: TextView,
        riskDetail: TextView,
        envLine: TextView,
        actionText: TextView,
        safeWindowsText: TextView
    ) {
        val activity = ctx.activity
        val rootShell = ctx.rootShell
        val lang = rootShell.settingsViewModel.state.preferredLanguage
        val session = ctx.session

        riskDetail.text = ctx.l("common.loading")
        Thread {
            rootShell.dashboardViewModel.refresh(
                userId = session.userId,
                accessToken = session.accessToken.ifBlank { null },
                profileId = session.profileId.ifBlank { null },
                persona = session.persona,
                lat = session.homeLat,
                lon = session.homeLon,
                language = lang,
                isGuest = session.isGuest
            )
            val state = rootShell.dashboardViewModel.state
            activity.runOnUiThread {
                riskValue.text = riskScoreText(state)
                badge.text = if (state.riskLevel == "-") "—" else state.riskLevel.uppercase()
                riskDetail.text = riskDetailText(state, lang)
                envLine.text = envText(state, lang)
                actionText.text = state.dailyActionsText().ifBlank { ctx.l("dashboard.no_actions") }
                safeWindowsText.text = state.safeWindowsText(ctx.l("dashboard.no_safe_window"))
            }
        }.start()
    }

    private fun briefingText(state: com.hiair.ui.DashboardState, lang: String): String {
        return when (state.loadState) {
            DashboardLoadState.LOADING -> if (lang == "en") "Loading briefing..." else "Загружаем брифинг..."
            DashboardLoadState.ERROR -> state.errorMessage
            DashboardLoadState.SUCCESS -> state.morningBriefing.ifBlank {
                if (lang == "en") "No briefing data yet." else "Данные брифинга пока недоступны."
            }
            else -> if (lang == "en") "Tap refresh to load data." else "Нажмите обновить для загрузки данных."
        }
    }

    private fun riskScoreText(state: com.hiair.ui.DashboardState): String {
        return when (state.loadState) {
            DashboardLoadState.LOADING -> "…"
            DashboardLoadState.SUCCESS -> state.riskScore?.toString() ?: "—"
            DashboardLoadState.ERROR -> "!"
            else -> "—"
        }
    }

    private fun riskDetailText(state: com.hiair.ui.DashboardState, lang: String): String {
        return when (state.loadState) {
            DashboardLoadState.LOADING -> if (lang == "en") "Loading..." else "Загрузка..."
            DashboardLoadState.ERROR -> state.errorMessage
            DashboardLoadState.SUCCESS -> listOf(state.headline, state.explanation).filter { it.isNotBlank() }.joinToString("\n")
            else -> if (lang == "en") "No data loaded." else "Данные не загружены."
        }
    }

    private fun envText(state: com.hiair.ui.DashboardState, lang: String): String {
        if (state.temperatureC == null || state.aqi == null) return ""
        return if (lang == "en") {
            "Temperature ${state.temperatureC}°C • AQI ${state.aqi}"
        } else {
            "Температура ${state.temperatureC}°C • AQI ${state.aqi}"
        }
    }
}
