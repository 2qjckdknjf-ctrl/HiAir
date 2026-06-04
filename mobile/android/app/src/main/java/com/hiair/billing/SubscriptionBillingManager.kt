package com.hiair.billing

import android.app.Activity
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
class SubscriptionBillingManager(
    private val activity: Activity,
    private val onPurchaseVerified: (productId: String, purchaseToken: String) -> Unit,
    private val onError: (String) -> Unit,
    private val onRestoreEmpty: (() -> Unit)? = null,
    private val onProductsLoaded: (() -> Unit)? = null,
) : PurchasesUpdatedListener {

    companion object {
        const val MONTHLY_PRODUCT_ID = "hiair_premium_monthly"
        const val YEARLY_PRODUCT_ID = "hiair_premium_yearly"
        val PRODUCT_IDS = listOf(MONTHLY_PRODUCT_ID, YEARLY_PRODUCT_ID)
    }

    private var billingClient: BillingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    private var productDetails: Map<String, ProductDetails> = emptyMap()

    fun start() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryProducts()
                } else {
                    onError("Billing setup failed: ${result.debugMessage}")
                }
            }

            override fun onBillingServiceDisconnected() {
                onError("Billing service disconnected")
            }
        })
    }

    fun queryProducts() {
        val products = PRODUCT_IDS.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder().setProductList(products).build()
        billingClient.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                onError(result.debugMessage)
                return@queryProductDetailsAsync
            }
            productDetails = details.associateBy { it.productId }
            activity.runOnUiThread { onProductsLoaded?.invoke() }
        }
    }

    fun launchPurchase(productId: String) {
        val details = productDetails[productId] ?: run {
            onError("Product not loaded: $productId")
            return
        }
        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
        if (offerToken == null) {
            onError("No subscription offer for $productId")
            return
        }
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offerToken)
            .build()
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()
        billingClient.launchBillingFlow(activity, flowParams)
    }

    fun restorePurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        billingClient.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                onError(result.debugMessage)
                return@queryPurchasesAsync
            }
            val purchased = purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
            if (purchased.isEmpty()) {
                activity.runOnUiThread { onRestoreEmpty?.invoke() }
                return@queryPurchasesAsync
            }
            purchased.forEach { handlePurchase(it) }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            onError(result.debugMessage)
            return
        }
        purchases?.forEach { handlePurchase(it) }
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        val productId = purchase.products.firstOrNull() ?: return
        if (!purchase.isAcknowledged) {
            val params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billingClient.acknowledgePurchase(params) { ackResult ->
                if (ackResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    onPurchaseVerified(productId, purchase.purchaseToken)
                } else {
                    onError(ackResult.debugMessage)
                }
            }
        } else {
            onPurchaseVerified(productId, purchase.purchaseToken)
        }
    }

    fun displayPrice(productId: String): String? {
        val details = productDetails[productId] ?: return null
        return details.subscriptionOfferDetails
            ?.firstOrNull()
            ?.pricingPhases
            ?.pricingPhaseList
            ?.firstOrNull()
            ?.formattedPrice
    }

    fun destroy() {
        billingClient.endConnection()
    }

    fun entitlementFromSubscriptionJson(raw: String): Boolean =
        SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(raw)
}
