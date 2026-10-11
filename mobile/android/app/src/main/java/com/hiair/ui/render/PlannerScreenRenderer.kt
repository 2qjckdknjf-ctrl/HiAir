package com.hiair.ui.render

import com.hiair.StoreScreenshotMode
import com.hiair.ui.planner.DailyPlannerViewModel

internal object PlannerScreenRenderer {
    fun render(ctx: RenderContext) {
        if (StoreScreenshotMode.active && ctx.rootShell.plannerViewModel.state.hourly.isEmpty()) {
            com.hiair.StoreScreenshotMockSeeder.apply(ctx.rootShell)
        }
        PlannerDeepGlassLayout.render(ctx)
        maybeAutoLoad(ctx)
    }

    private fun maybeAutoLoad(ctx: RenderContext) {
        if (StoreScreenshotMode.active || ctx.presentationOnly) return
        val rootShell = ctx.rootShell
