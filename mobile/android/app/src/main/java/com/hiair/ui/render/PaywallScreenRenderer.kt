package com.hiair.ui.render

import android.widget.LinearLayout
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.config.HiAirLegalUrls
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.theme.V2Ui

internal object PaywallScreenRenderer {
    fun render(ctx: RenderContext, paywall: SubscriptionPaywallController) {
        val activity = ctx.activity
        val settings = ctx.rootShell.settingsViewModel
        val state = settings.state

        paywall.attach(activity)
        paywall.refreshPrices()

        val monthlyPrice = paywall.monthlyPrice
        val yearlyPrice = paywall.yearlyPrice

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

            if (monthlyPrice == null && yearlyPrice == null) {
                addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.catalog_unavailable")))
                addView(V2Ui.spacer(activity, 8))
            }

            val monthlyLabel = monthlyPrice?.let { "${ctx.l("paywall.plan_monthly")} — $it" }
                ?: ctx.l("paywall.plan_monthly")
            addView(HiAirComponents.primaryButton(activity, monthlyLabel).apply {
                contentDescription = monthlyLabel
                isEnabled = monthlyPrice != null
                alpha = if (monthlyPrice != null) 1f else 0.45f
                setOnClickListener {
                    if (monthlyPrice == null) return@setOnClickListener
                    settings.setPaywallStatus(ctx.l("paywall.purchasing"))
                    paywall.purchaseMonthly(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            val yearlyLabel = yearlyPrice?.let { "${ctx.l("paywall.plan_yearly")} — $it" }
                ?: ctx.l("paywall.plan_yearly")
            addView(HiAirComponents.primaryButton(activity, yearlyLabel).apply {
                contentDescription = yearlyLabel
                isEnabled = yearlyPrice != null
                alpha = if (yearlyPrice != null) 1f else 0.45f
                setOnClickListener {
                    if (yearlyPrice == null) return@setOnClickListener
                    settings.setPaywallStatus(ctx.l("paywall.purchasing"))
                    paywall.purchaseYearly(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            addView(HiAirComponents.secondaryButton(activity, ctx.l("paywall.restore")).apply {
                contentDescription = ctx.l("paywall.restore")
                setOnClickListener {
                    settings.setPaywallStatus(ctx.l("paywall.restoring"))
                    paywall.restore(activity)
                }
            })
            addView(V2Ui.spacer(activity, 8))

            addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.legal_auto_renew")))
            addView(V2Ui.spacer(activity, 8))

            addView(HiAirComponents.secondaryButton(activity, ctx.l("paywall.terms")).apply {
                contentDescription = ctx.l("paywall.terms")
                setOnClickListener {
                    if (!HiAirLegalUrls.openTerms(activity)) {
                        settings.setPaywallStatus(ctx.l("paywall.browser_unavailable"))
                    }
                }
            })
            addView(V2Ui.spacer(activity, 4))
            addView(HiAirComponents.secondaryButton(activity, ctx.l("paywall.privacy")).apply {
                contentDescription = ctx.l("paywall.privacy")
                setOnClickListener {
                    if (!HiAirLegalUrls.openPrivacy(activity)) {
                        settings.setPaywallStatus(ctx.l("paywall.browser_unavailable"))
                    }
                }
            })
            addView(V2Ui.spacer(activity, 8))

            addView(HiAirComponents.secondaryButton(activity, ctx.l("common.close")).apply {
                contentDescription = ctx.l("common.close")
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
