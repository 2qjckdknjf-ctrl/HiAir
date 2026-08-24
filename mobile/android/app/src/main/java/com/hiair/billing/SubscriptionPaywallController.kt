package com.hiair.billing

import androidx.appcompat.app.AppCompatActivity
import com.hiair.ui.settings.SettingsViewModel

/**
 * Connects Google Play Billing to backend verify/restore and SettingsViewModel entitlement state.
 */
class SubscriptionPaywallController(
    private val settingsViewModel: SettingsViewModel,
) {
    private var billingManager: SubscriptionBillingManager? = null

    var monthlyPrice: String? = null
        private set
    var yearlyPrice: String? = null
        private set
    var lastError: String? = null
        private set

    fun attach(activity: AppCompatActivity) {
        if (com.hiair.BuildConfig.DEBUG && com.hiair.StoreScreenshotMode.active) {
            monthlyPrice = "$4.99"
            yearlyPrice = "$39.99"
            return
        }
        if (billingManager != null) return
        billingManager = SubscriptionBillingManager(
            activity = activity,
            onPurchaseVerified = { productId, token ->
                settingsViewModel.verifyAndroidPurchase(productId, token) { activated ->
                    activity.runOnUiThread {
                        if (activated) {
                            settingsViewModel.dismissPaywall()
                        }
                        onEntitlementUpdated?.invoke()
                    }
                }
            },
            onError = { message ->
                lastError = message
                activity.runOnUiThread {
                    settingsViewModel.setPaywallStatus(message)
                    onEntitlementUpdated?.invoke()
                }
            },
            onRestoreEmpty = {
                settingsViewModel.finalizeRestoreFromStore {
                    activity.runOnUiThread { onEntitlementUpdated?.invoke() }
                }
            },
            onProductsLoaded = {
                refreshPrices()
                activity.runOnUiThread { onEntitlementUpdated?.invoke() }
            },
        ).also { it.start() }
    }

    var onEntitlementUpdated: (() -> Unit)? = null

    fun refreshPrices() {
        monthlyPrice = billingManager?.displayPrice(SubscriptionBillingManager.MONTHLY_PRODUCT_ID)
        yearlyPrice = billingManager?.displayPrice(SubscriptionBillingManager.YEARLY_PRODUCT_ID)
    }

    fun purchaseMonthly(activity: AppCompatActivity) {
        attach(activity)
        billingManager?.launchPurchase(SubscriptionBillingManager.MONTHLY_PRODUCT_ID)
    }

    fun purchaseYearly(activity: AppCompatActivity) {
        attach(activity)
        billingManager?.launchPurchase(SubscriptionBillingManager.YEARLY_PRODUCT_ID)
    }

    fun restore(activity: AppCompatActivity) {
        attach(activity)
        settingsViewModel.setPaywallStatus("")
        billingManager?.restorePurchases()
    }

    fun destroy() {
        billingManager?.destroy()
        billingManager = null
    }
}
