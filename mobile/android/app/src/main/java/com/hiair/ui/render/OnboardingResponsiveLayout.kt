package com.hiair.ui.render

import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.hiair.OnboardingStore
import com.hiair.R
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirLayoutMode
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirScreenMetrics
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.HiAirV4Glass
import com.hiair.ui.design.HiAirV4Presentation
import com.hiair.ui.design.markGeometry
import com.hiair.ui.theme.V2Ui

internal object OnboardingResponsiveLayout {
    fun renderStoreScreenshotWelcome(
        ctx: RenderContext,
        onboardingStore: OnboardingStore,
        onComplete: () -> Unit,
    ) {
        val ctx = ctx.withStoreContentRoot("onboarding")
        val activity = ctx.activity
        val widthDp = HiAirResponsiveLayout.screenWidthDp(activity)
        val mode = HiAirResponsiveLayout.layoutMode(activity)
        val landscapeSplit = HiAirV4Presentation.shouldUseLandscapeSplit(activity)
        val orbSize = HiAirScreenMetrics.heroOrbDp(widthDp).coerceAtMost(
            when {
                landscapeSplit -> 140
                mode == HiAirLayoutMode.TABLET -> 170
                mode == HiAirLayoutMode.EXPANDED -> 180
                else -> 200
            },
        )

        val brandHero = if (landscapeSplit) {
            HiAirV4Presentation.onboardingBrandHero(
                activity,
                orbSizeDp = orbSize,
                tagline = ctx.l("onboarding.tagline"),
                subtitle = ctx.l("onboarding.step1.body"),
            ).markGeometry(HiAirGeometryMarkers.ONBOARDING_HERO)
        } else {
            null
        }

        val features = buildFeaturesGrid(ctx, compact = !landscapeSplit).markGeometry(HiAirGeometryMarkers.ONBOARDING_FEATURES)
        val locationCard = HiAirV4Glass.featureRow(
            activity,
            iconRes = R.drawable.ic_v4_location,
            title = ctx.l("onboarding.step5.title"),
            body = ctx.l("onboarding.permissions.location.body"),
        ).markGeometry(HiAirGeometryMarkers.ONBOARDING_LOCATION)

        val progress = V2Ui.styledSecondaryText(activity, ctx.l("onboarding.progress.step1")).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            textSize = 12f
            markGeometry(HiAirGeometryMarkers.ONBOARDING_PROGRESS)
        }
        val getStarted = HiAirComponents.primaryButton(activity, ctx.l("onboarding.next")).apply {
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
            markGeometry(HiAirGeometryMarkers.ONBOARDING_PRIMARY_CTA)
            setOnClickListener {
                onboardingStore.setCompleted(true)
                onComplete()
            }
        }
        val guest = HiAirComponents.secondaryButton(activity, ctx.l("onboarding.permissions.later")).apply {
            layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
            markGeometry(HiAirGeometryMarkers.ONBOARDING_SECONDARY_CTA)
            setOnClickListener {
                onboardingStore.setCompleted(true)
                onComplete()
            }
        }

        if (!landscapeSplit) {
            val portraitOrb = when (mode) {
                HiAirLayoutMode.TABLET, HiAirLayoutMode.EXPANDED -> orbSize.coerceAtMost(120)
                else -> orbSize
            }
            val brandHeroPortrait = HiAirV4Presentation.onboardingBrandHero(
                activity,
                orbSizeDp = portraitOrb,
                tagline = ctx.l("onboarding.tagline"),
                subtitle = ctx.l("onboarding.step1.body"),
                compact = mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED,
            ).markGeometry(HiAirGeometryMarkers.ONBOARDING_HERO)
            val column = HiAirV4Presentation.boundedCanvasHost(activity).apply {
                gravity = Gravity.CENTER_HORIZONTAL or Gravity.TOP
            }
            column.addView(brandHeroPortrait)
            listOf(features, locationCard, getStarted, guest, progress).forEachIndexed { index, view ->
                if (index > 0) {
                    column.addView(V2Ui.spacer(activity, HiAirSpacing.xxs))
                }
                column.addView(view)
            }
            if (HiAirV4Presentation.shouldCenterOnboardingPortrait(activity)) {
                ctx.bodyContainer.layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.MATCH_PARENT,
                )
                val host = HiAirV4Presentation.viewportCenteredHost(activity)
                host.addView(column)
                ctx.bodyContainer.addView(host)
            } else {
                ctx.bodyContainer.addView(column)
            }
            return
        }

        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = HiAirV4Presentation.boundedCanvasLayoutParams(activity).apply {
                width = HiAirResponsiveLayout.availableContentWidthPx(activity)
            }
        }
        val left = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 0.95f)
        }
        left.addView(brandHero!!)
        val right = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.05f).apply {
                marginStart = V2Ui.dp(activity, HiAirSpacing.md)
            }
        }
        right.addView(features)
        right.addView(locationCard)
        right.addView(V2Ui.spacer(activity, HiAirSpacing.xs))
        right.addView(getStarted)
        right.addView(guest)
        right.addView(progress)
        root.addView(left)
        root.addView(right)
        ctx.bodyContainer.addView(root)
    }

    private fun buildFeaturesGrid(ctx: RenderContext, compact: Boolean = false): LinearLayout {
        val activity = ctx.activity
        val cards = listOf(
            HiAirV4Glass.featureRow(
                activity,
                iconRes = R.drawable.ic_v4_heat,
                title = featureTitle(ctx, "heat"),
                body = ctx.l("onboarding.problem.heat"),
            ),
            HiAirV4Glass.featureRow(
                activity,
                iconRes = R.drawable.ic_v4_air,
                title = featureTitle(ctx, "air"),
                body = ctx.l("onboarding.problem.pm25"),
            ),
            HiAirV4Glass.featureRow(
                activity,
                iconRes = R.drawable.ic_v4_uv,
                title = featureTitle(ctx, "uv"),
                body = ctx.l("onboarding.problem.ozone"),
            ),
        )
        return LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            val maxW = minOf(
                V2Ui.dp(activity, 520),
                HiAirResponsiveLayout.availableContentWidthPx(activity),
            )
            cards.forEachIndexed { index, card ->
                if (compact && index > 0) {
                    addView(V2Ui.spacer(activity, HiAirSpacing.xxs))
                }
                addView(
                    LinearLayout(activity).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                        addView(
                            card,
                            LinearLayout.LayoutParams(maxW, LinearLayout.LayoutParams.WRAP_CONTENT),
                        )
                    },
                )
            }
        }
    }

    private fun featureTitle(ctx: RenderContext, kind: String): String {
        return when (kind) {
            "heat" -> if (ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")) "Жара" else "Heat"
            "air" -> if (ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")) "Воздух" else "Air quality"
            else -> if (ctx.rootShell.settingsViewModel.state.preferredLanguage.startsWith("ru")) "УФ и озон" else "UV & ozone"
        }
    }
}
