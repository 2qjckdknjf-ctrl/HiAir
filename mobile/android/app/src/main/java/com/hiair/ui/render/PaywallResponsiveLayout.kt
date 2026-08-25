package com.hiair.ui.render

import android.view.Gravity
import android.widget.LinearLayout
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.accessibility.HiAirGeometryMarkers
import com.hiair.ui.config.HiAirLegalUrls
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.design.HiAirGridLayout
import com.hiair.ui.design.HiAirLayoutMode
import com.hiair.ui.design.HiAirResponsiveLayout
import com.hiair.ui.design.HiAirSpacing
import com.hiair.ui.design.HiAirV4Presentation
import com.hiair.ui.design.markGeometry
import com.hiair.ui.theme.V2Ui

internal object PaywallResponsiveLayout {
    const val PLAN_MONTHLY = "monthly"
    const val PLAN_YEARLY = "yearly"

    fun render(ctx: RenderContext, paywall: SubscriptionPaywallController) {
        val ctx = ctx.withStoreContentRoot("paywall")
        val activity = ctx.activity
        val settingsVm = ctx.rootShell.settingsViewModel
        val state = settingsVm.state
        val monthlyPrice = paywall.monthlyPrice
        val yearlyPrice = paywall.yearlyPrice
        val mode = HiAirResponsiveLayout.layoutMode(activity)

        val canvas = HiAirV4Presentation.boundedCanvasHost(activity).apply {
            markGeometry(HiAirGeometryMarkers.PAYWALL_CANVAS)
        }

        canvas.addView(
            HiAirV4Presentation.paywallHeroBlock(
                activity,
                title = ctx.l("paywall.title"),
                subtitle = ctx.l("paywall.subtitle"),
            ),
        )
        canvas.addView(V2Ui.spacer(activity, HiAirSpacing.sm))

        val benefitsCard = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.PAYWALL_BENEFITS)
        }
        val benefitIcons = listOf(
            com.hiair.R.drawable.ic_v4_air,
            com.hiair.R.drawable.ic_v4_ventilation,
            com.hiair.R.drawable.ic_v4_heart,
            com.hiair.R.drawable.ic_v4_location,
            com.hiair.R.drawable.ic_v4_recovery,
        )
        listOf(
            ctx.l("paywall.benefit.profiles"),
            ctx.l("paywall.benefit.forecast"),
            ctx.l("paywall.benefit.alerts"),
            ctx.l("paywall.benefit.export"),
            ctx.l("paywall.benefit.insights"),
        ).forEachIndexed { index, line ->
            benefitsCard.addView(
                LinearLayout(activity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(V2Ui.dp(activity, HiAirSpacing.sm), V2Ui.dp(activity, HiAirSpacing.sm), V2Ui.dp(activity, HiAirSpacing.sm), V2Ui.dp(activity, HiAirSpacing.sm))
                    background = com.hiair.ui.design.HiAirV4Glass.surfaceBackground(activity)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply { topMargin = V2Ui.dp(activity, HiAirSpacing.xs) }
                    addView(com.hiair.ui.design.HiAirV4Glass.iconContainer(activity, benefitIcons[index]))
                    addView(
                        V2Ui.styledBodyText(activity, line).apply {
                            textSize = 14f
                            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                                marginStart = V2Ui.dp(activity, HiAirSpacing.sm)
                            }
                        },
                    )
                },
            )
        }
        canvas.addView(benefitsCard)
        canvas.addView(V2Ui.spacer(activity, HiAirSpacing.sm))

        if (monthlyPrice == null && yearlyPrice == null) {
            canvas.addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.catalog_unavailable")))
            canvas.addView(V2Ui.spacer(activity, HiAirSpacing.xs))
        }

        val monthlyCard = planCard(
            ctx,
            planId = PLAN_MONTHLY,
            title = ctx.l("paywall.plan_monthly"),
            price = monthlyPrice,
            selected = state.paywallSelectedPlanId == PLAN_MONTHLY,
            settingsVm = settingsVm,
            paywall = paywall,
        )
        val yearlyCard = planCard(
            ctx,
            planId = PLAN_YEARLY,
            title = ctx.l("paywall.plan_yearly"),
            price = yearlyPrice,
            selected = state.paywallSelectedPlanId == PLAN_YEARLY,
            settingsVm = settingsVm,
            paywall = paywall,
        )

        val plansHost = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            markGeometry(HiAirGeometryMarkers.PAYWALL_PLANS)
        }
        if (mode == HiAirLayoutMode.TABLET || mode == HiAirLayoutMode.EXPANDED) {
            HiAirGridLayout.addAdaptiveGridRows(
                plansHost,
                activity,
                requestedColumns = 2,
                views = listOf(monthlyCard, yearlyCard),
                minItemWidthDp = 180,
            )
        } else {
            plansHost.addView(monthlyCard)
            plansHost.addView(V2Ui.spacer(activity, HiAirSpacing.xs))
            plansHost.addView(yearlyCard)
        }
        canvas.addView(plansHost)
        canvas.addView(V2Ui.spacer(activity, HiAirSpacing.sm))

        canvas.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("paywall.restore")).apply {
                layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                markGeometry(HiAirGeometryMarkers.PAYWALL_RESTORE)
                setOnClickListener {
                    settingsVm.setPaywallStatus(ctx.l("paywall.restoring"))
                    paywall.restore(activity)
                }
            },
        )

        val legal = V2Ui.styledSecondaryText(activity, ctx.l("paywall.legal_auto_renew")).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            markGeometry(HiAirGeometryMarkers.PAYWALL_LEGAL)
        }
        canvas.addView(legal)

        val legalRow = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
        listOf(
            HiAirComponents.secondaryButton(activity, ctx.l("paywall.terms")).apply {
                layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                markGeometry(HiAirGeometryMarkers.PAYWALL_TERMS)
                setOnClickListener {
                    if (!HiAirLegalUrls.openTerms(activity)) {
                        settingsVm.setPaywallStatus(ctx.l("paywall.browser_unavailable"))
                    }
                }
            },
            HiAirComponents.secondaryButton(activity, ctx.l("paywall.privacy")).apply {
                layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                markGeometry(HiAirGeometryMarkers.PAYWALL_PRIVACY)
                setOnClickListener {
                    if (!HiAirLegalUrls.openPrivacy(activity)) {
                        settingsVm.setPaywallStatus(ctx.l("paywall.browser_unavailable"))
                    }
                }
            },
        ).forEach { legalRow.addView(it) }
        canvas.addView(legalRow)

        canvas.addView(
            HiAirComponents.secondaryButton(activity, ctx.l("common.close")).apply {
                layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                markGeometry(HiAirGeometryMarkers.PAYWALL_CLOSE)
                setOnClickListener {
                    settingsVm.dismissPaywall()
                    ctx.rerender()
                }
            },
        )

        if (state.paywallStatusText.isNotBlank()) {
            canvas.addView(V2Ui.styledSecondaryText(activity, state.paywallStatusText))
        }
        paywall.lastError?.let { err ->
            canvas.addView(V2Ui.styledSecondaryText(activity, err))
        }
        canvas.addView(
            V2Ui.styledSecondaryText(activity, ctx.l("paywall.disclaimer")).apply {
                textSize = 11f
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )

        ctx.bodyContainer.addView(canvas)
    }

    private fun planCard(
        ctx: RenderContext,
        planId: String,
        title: String,
        price: String?,
        selected: Boolean,
        settingsVm: com.hiair.ui.settings.SettingsViewModel,
        paywall: SubscriptionPaywallController,
    ): LinearLayout {
        val activity = ctx.activity
        val label = price?.let { "$title — $it" } ?: title
        val marker = if (planId == PLAN_MONTHLY) {
            HiAirGeometryMarkers.PAYWALL_PLAN_MONTHLY
        } else {
            HiAirGeometryMarkers.PAYWALL_PLAN_YEARLY
        }
        return HiAirComponents.glassAccentContainer(activity).apply {
            orientation = LinearLayout.VERTICAL
            alpha = if (selected) 1f else 0.94f
            markGeometry(marker)
            addView(V2Ui.styledBodyText(activity, title).apply { textSize = 16f })
            price?.let {
                addView(V2Ui.styledSecondaryText(activity, it).apply { textSize = 18f })
            }
            addView(V2Ui.spacer(activity, HiAirSpacing.xs))
            addView(
                HiAirComponents.primaryButton(activity, label).apply {
                    layoutParams = HiAirResponsiveLayout.constrainedButtonLayoutParams(activity)
                    isEnabled = price != null
                    alpha = if (price != null) 1f else 0.45f
                    markGeometry(HiAirGeometryMarkers.PAYWALL_PURCHASE_CTA)
                    setOnClickListener {
                        settingsVm.setPaywallSelectedPlanId(planId)
                        if (price == null) return@setOnClickListener
                        settingsVm.setPaywallStatus(ctx.l("paywall.purchasing"))
                        if (planId == PLAN_MONTHLY) {
                            paywall.purchaseMonthly(activity)
                        } else {
                            paywall.purchaseYearly(activity)
                        }
                    }
                },
            )
        }
    }
}
