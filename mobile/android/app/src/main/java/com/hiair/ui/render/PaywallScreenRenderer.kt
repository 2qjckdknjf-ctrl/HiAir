package com.hiair.ui.render

import com.hiair.billing.SubscriptionPaywallController

internal object PaywallScreenRenderer {
    fun render(ctx: RenderContext, paywall: SubscriptionPaywallController) {
        val activity = ctx.activity
        paywall.attach(activity)
        paywall.refreshPrices()
        PaywallResponsiveLayout.render(ctx, paywall)
    }
}
