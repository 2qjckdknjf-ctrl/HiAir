package com.hiair.ui.render

import com.hiair.StoreScreenshotMode
import com.hiair.ui.planner.DailyPlannerViewModel

internal object PlannerScreenRenderer {
    fun render(ctx: RenderContext) {
        PlannerDeepGlassLayout.render(ctx)
        maybeAutoLoad(ctx)
    }

    private fun maybeAutoLoad(ctx: RenderContext) {
        if (StoreScreenshotMode.active) return
        val rootShell = ctx.rootShell
        val plannerState = rootShell.plannerViewModel.state
        if (
            !rootShell.plannerViewModel.hasAttemptedAutoLoad &&
            !plannerState.loading &&
            plannerState.hourly.isEmpty() &&
            !plannerState.premiumRequired
        ) {
            rootShell.plannerViewModel.hasAttemptedAutoLoad = true
            Thread {
                val resolvedProfileId = rootShell.settingsViewModel.ensureProfile()
                val settings = rootShell.settingsViewModel.state
                val profileId = resolvedProfileId
                    ?: rootShell.symptomLogViewModel.state.profileId.ifBlank { "" }
                if (profileId.isBlank()) return@Thread
                rootShell.plannerViewModel.refresh(
                    userId = settings.userId,
                    accessToken = settings.accessToken.ifBlank { null },
                    profileId = profileId,
                    preferredLanguage = settings.preferredLanguage,
                )
                ctx.activity.runOnUiThread { ctx.rerender() }
            }.start()
        }
    }
}
