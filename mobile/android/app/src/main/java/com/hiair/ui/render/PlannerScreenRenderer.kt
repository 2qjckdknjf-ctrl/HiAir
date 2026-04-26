package com.hiair.ui.render

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
        plannerCard.addView(stateText)
        bodyContainer.addView(plannerCard)

        val refreshButton = V2Ui.primaryButton(activity, ctx.l("planner.refresh")).apply {
            setOnClickListener {
                stateText.text = ctx.l("common.loading")
                Thread {
                    val settings = rootShell.settingsViewModel.state
                    val profileId = settings.profileId.ifBlank {
                        rootShell.symptomLogViewModel.state.profileId
                    }
                    if (profileId.isBlank()) {
                        activity.runOnUiThread { stateText.text = ctx.l("planner.profile_required") }
                        return@Thread
                    }
                    rootShell.plannerViewModel.refresh(
                        userId = settings.userId,
                        accessToken = settings.accessToken.ifBlank { null },
                        profileId = profileId,
                        language = settings.preferredLanguage
                    )
                    val state = rootShell.plannerViewModel.state
                    activity.runOnUiThread {
                        stateText.text = "${state.statusText}\n\n${ctx.l("dashboard.safe_windows")}:\n" +
                            state.safeWindows.joinToString("\n") { "• $it" } +
                            "\n\n${ctx.l("planner.hourly")}:\n" +
                            state.hourly.joinToString("\n") { "• $it" }
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
}
