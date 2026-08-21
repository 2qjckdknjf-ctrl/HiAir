package com.hiair.ui.render

import android.content.Intent
import android.net.Uri
import android.widget.LinearLayout
import com.hiair.billing.SubscriptionPaywallController
import com.hiair.ui.design.HiAirComponents
import com.hiair.ui.theme.V2Ui

internal object PaywallScreenRenderer {
    private const val TERMS_URL = "https://hiair.io/terms/"
    private const val PRIVACY_URL = "https://hiair.io/privacy/"

    fun render(ctx: RenderContext, paywall: SubscriptionPaywallController) {
        val activity = ctx.activity
        val settings = ctx.rootShell.settingsViewModel
        val state = settings.state

        paywall.attach(activity)
        paywall.refreshPrices()

        ctx.bodyContainer.apply {
            addView(
                HiAirComponents.screenWordmark(
                    activity,
                    ctx.l("paywall.title").removePrefix("HiAir ").ifBlank { ctx.l("paywall.title") },
                )
            )
            HiAirComponents.hidePageTitle(ctx.titleView)
            addView(V2Ui.styledBodyText(activity, ctx.l("paywall.subtitle")))
            addView(V2Ui.spacer(activity, 12))

            // Play / store subscription disclosure (title, length, price, Terms, Privacy).
            val factsCard = HiAirComponents.cardContainer(activity)
            factsCard.addView(HiAirComponents.sectionTitle(activity, ctx.l("paywall.required_info")))
            factsCard.addView(V2Ui.styledBodyText(activity, ctx.l("paywall.offer_title_monthly")))
            factsCard.addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.length_month")))
            factsCard.addView(
                V2Ui.styledBodyText(
                    activity,
                    paywall.monthlyPrice ?: ctx.l("paywall.price_pending"),
                )
            )
            factsCard.addView(V2Ui.spacer(activity, 8))
            factsCard.addView(V2Ui.styledBodyText(activity, ctx.l("paywall.offer_title_yearly")))
            factsCard.addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.length_year")))
            factsCard.addView(
                V2Ui.styledBodyText(
                    activity,
                    paywall.yearlyPrice ?: ctx.l("paywall.price_pending"),
                )
            )
            factsCard.addView(V2Ui.spacer(activity, 8))
            factsCard.addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.service_period")))
            factsCard.addView(
                HiAirComponents.secondaryButton(activity, ctx.l("paywall.terms")).apply {
                    setOnClickListener { openUrl(ctx, TERMS_URL) }
                }
            )
            factsCard.addView(
                HiAirComponents.secondaryButton(activity, ctx.l("paywall.privacy")).apply {
                    setOnClickListener { openUrl(ctx, PRIVACY_URL) }
                }
            )
            addView(factsCard)
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
            addView(V2Ui.styledSecondaryText(activity, ctx.l("paywall.legal_auto_renew")))
            addView(V2Ui.spacer(activity, 8))
            addView(HiAirComponents.secondaryButton(activity, ctx.l("settings.manage_subscription")).apply {
                setOnClickListener {
                    openUrl(ctx, "https://play.google.com/store/account/subscriptions")
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

    private fun openUrl(ctx: RenderContext, url: String) {
        runCatching {
            ctx.activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }
    }
}
