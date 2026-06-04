package com.hiair.ui.render

import android.widget.LinearLayout
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.theme.V2Ui

internal object PaywallScreenRenderer {
    fun render(ctx: RenderContext, paywall: SubscriptionPaywallController) {
        val activity = ctx.activity
        val settings = ctx.rootShell.settingsViewModel
        val state = settings.state

        paywall.attach(activity)
        paywall.refreshPrices()

        ctx.bodyContainer.apply {
            addView(HiAirComponents.brandHeader(activity))
            ctx.titleView.text = ctx.l("paywall.title")
            addView(V2Ui.styledBodyText(activity, ctx.l("paywall.subtitle")))
            addView(V2Ui.spacer(activity, 12))

            val benefits = listOf(
                ctx.l("paywall.benefit.profiles"),
                ctx.l("paywall.benefit.forecast"),
                ctx.l("paywall.benefit.alerts"),
                ctx.l("paywall.benefit.export"),
                ctx.l("paywall.benefit.insights"),
            )
            val benefitsCard = HiAirComponents.cardContainer(activity)
            benefits.forEach { line ->
                benefitsCard.addView(V2Ui.styledBodyText(activity, "✓ $line"))
            }
            addView(benefitsCard)
            addView(V2Ui.spacer(activity, 12))

            val monthlyLabel = paywall.monthlyPrice?.let { "${ctx.l("paywall.monthly")} — $it" }
                ?: ctx.l("paywall.monthly")
            addView(HiAirComponents.primaryButton(activity, monthlyLabel).apply {
                setOnClickListener {
                    settings.setPaywallStatus(ctx.l("paywall.purchasing"))
                    paywall.purchaseMonthly(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            val yearlyLabel = paywall.yearlyPrice?.let { "${ctx.l("paywall.yearly")} — $it" }
                ?: ctx.l("paywall.yearly")
            addView(HiAirComponents.primaryButton(activity, yearlyLabel).apply {
                setOnClickListener {
                    settings.setPaywallStatus(ctx.l("paywall.purchasing"))
                    paywall.purchaseYearly(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            addView(HiAirComponents.secondaryButton(activity, ctx.l("paywall.restore")).apply {
                setOnClickListener {
                    settings.setPaywallStatus(ctx.l("paywall.restoring"))
                    paywall.restore(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            addView(HiAirComponents.secondaryButton(activity, ctx.l("common.close")).apply {
                setOnClickListener {
                    settings.dismissPaywall()
                    ctx.rerender()
                }
            })

            if (state.paywallStatusText.isNotBlank()) {
                addView(V2Ui.spacer(activity, 8))
                addView(V2Ui.styledSecondaryText(activity, state.paywallStatusText))
            }
            paywall.lastError?.let { err ->
                addView(V2Ui.styledSecondaryText(activity, err))
            }

            addView(V2Ui.spacer(activity, 12))
            addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.disclaimer")))
        }
    }

}
