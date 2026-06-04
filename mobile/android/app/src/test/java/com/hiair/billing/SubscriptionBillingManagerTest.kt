package com.hiair.billing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionBillingManagerTest {

    @Test
    fun productIds_matchBackendCatalog() {
        assertEquals("hiair_premium_monthly", SubscriptionBillingManager.MONTHLY_PRODUCT_ID)
        assertEquals("hiair_premium_yearly", SubscriptionBillingManager.YEARLY_PRODUCT_ID)
        assertTrue(SubscriptionBillingManager.PRODUCT_IDS.contains(SubscriptionBillingManager.MONTHLY_PRODUCT_ID))
    }

    @Test
    fun entitlementFromSubscriptionJson_delegatesToParser() {
        val premiumJson = """{"entitlement":{"is_premium":true}}"""
        val freeJson = """{"entitlement":{"is_premium":false}}"""
        assertTrue(SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(premiumJson))
        assertFalse(SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(freeJson))
    }
}
