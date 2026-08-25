package com.hiair.ui.render

import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.ui.DashboardState
import com.hiair.ui.DashboardViewModel
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirGridLayout
import com.hiair.ui.design.HiAirLayoutMode
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.Tokens
import com.hiair.ui.design.markGeometry
import com.hiair.ui.theme.V2Ui
import java.util.Locale

/** Presentation-only dashboard reflow helpers (no business logic). */
internal object DashboardResponsiveLayout {
    fun heroCardLayoutParams(ctx: RenderContext): LinearLayout.LayoutParams {
        val mode = HiAirResponsiveLayout.layoutMode(ctx.activity)
        val snapshot = HiAirResponsiveLayout.windowSnapshot(ctx.activity)
        // Bound medium/tablet/expanded heroes so the orb stays centered without an empty right half.
        val maxHeroDp = when (mode) {
            HiAirLayoutMode.COMPACT -> snapshot.innerAvailableWidthDp
            HiAirLayoutMode.STANDARD -> minOf(380, snapshot.innerAvailableWidthDp)
            HiAirLayoutMode.TABLET -> 340
            HiAirLayoutMode.EXPANDED -> 420
        }
        val maxWidthPx = minOf(
            V2Ui.dp(ctx.activity, maxHeroDp),
            snapshot.finalContentWidthPx,
        )
        return LinearLayout.LayoutParams(maxWidthPx, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        }
    }

    fun weatherAqiSection(ctx: RenderContext, state: DashboardState): View? {
        val activity = ctx.activity
        val temp = state.temperatureC ?: return null
        val aqi = state.aqi ?: return null
        val tempTile = HiAirComponents.glassMetricTile(
            activity,
            ctx.l("dashboard.metric_temp"),
            "${round1(temp)}°C",
            state.feelsLikeC?.let { "${ctx.l("dashboard.metric_feels")} ${round1(it)}°C" }
                ?: ctx.l("dashboard.source_live"),
        )
        val aqiTile = HiAirComponents.glassMetricTile(
            activity,
            ctx.l("dashboard.metric_aqi"),
            aqi.toString(),
            state.pm25?.let { "PM2.5 ${round1(it)} µg/m³" } ?: ctx.l("dashboard.source_live"),
        )
        val host = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.DASHBOARD_WEATHER_GRID)
        }
        HiAirGridLayout.addAdaptiveGridRows(host, activity, requestedColumns = 2, listOf(tempTile, aqiTile))
        return host
    }

    fun recommendationsSection(ctx: RenderContext, state: DashboardState): View {
        val activity = ctx.activity
        val card = HiAirComponents.cardContainer(activity).markGeometry(HiAirGeometryMarkers.DASHBOARD_RECOMMENDATIONS)
        card.addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.do_now")).apply { textSize = 16f })
        card.addView(V2Ui.spacer(activity, 6))
        if (state.actions.isEmpty()) {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.no_actions")))
            return card
        }
        val mode = HiAirResponsiveLayout.layoutMode(activity)
        val maxCols = when (mode) {
            HiAirLayoutMode.EXPANDED -> 3
            HiAirLayoutMode.TABLET -> 2
            else -> 1
        }
        val tiles = state.actions.map { action -> actionTile(activity, "• $action") }
        if (maxCols == 1) {
            tiles.forEach { card.addView(it) }
        } else {
            val gridHost = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
            HiAirGridLayout.addAdaptiveGridRows(
                gridHost,
                activity,
                requestedColumns = maxCols,
                views = tiles,
                minItemWidthDp = HiAirGridLayout.MIN_CARD_WIDTH_DP,
            )
            card.addView(gridHost)
        }
        return card
    }

    fun safeWindowsSection(ctx: RenderContext, state: DashboardState): View {
        val activity = ctx.activity
        val mode = HiAirResponsiveLayout.layoutMode(activity)
        val card = HiAirComponents.cardContainer(activity).apply {
            markGeometry(HiAirGeometryMarkers.DASHBOARD_SAFE_WINDOWS)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        card.addView(V2Ui.styledBodyText(activity, ctx.l("dashboard.safe_windows")))
        if (state.safeWindows.isEmpty()) {
            card.addView(V2Ui.styledSecondaryText(activity, ctx.l("dashboard.no_safe_windows")))
        } else {
            state.safeWindows.forEach { window -> card.addView(safePill(activity, window)) }
        }
        return card
    }

    fun boundedPrimaryCta(ctx: RenderContext, label: String, onClick: () -> Unit): View {
        return HiAirComponents.primaryButton(ctx.activity, label).apply {
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(ctx.activity)
            markGeometry(HiAirGeometryMarkers.DASHBOARD_PRIMARY_CTA)
            setOnClickListener { onClick() }
        }
    }

    fun boundedSecondaryCta(ctx: RenderContext, label: String, onClick: () -> Unit): View {
        return HiAirComponents.secondaryButton(ctx.activity, label).apply {
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(ctx.activity)
            setOnClickListener { onClick() }
        }
    }

    private fun actionTile(activity: android.app.Activity, text: String): TextView {
        return V2Ui.styledSecondaryText(activity, text).apply {
            textSize = 13f
            setTextColor(Tokens.Text.primary)
            setPadding(V2Ui.dp(activity, 10), V2Ui.dp(activity, 8), V2Ui.dp(activity, 10), V2Ui.dp(activity, 8))
            background = HiAirComponents.tileBackground(activity)
            gravity = Gravity.START
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
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = V2Ui.dp(activity, 6) }
        }
    }

    private fun round1(value: Double): String = String.format(Locale.US, "%.1f", value)
}
