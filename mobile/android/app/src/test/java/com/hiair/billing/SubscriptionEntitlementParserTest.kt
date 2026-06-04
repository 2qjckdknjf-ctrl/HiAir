package com.hiair.billing

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SubscriptionEntitlementParserTest {

    @Test
    fun entitlementJson_premiumFlag() {
        val premiumJson = """{"entitlement":{"is_premium":true,"plan":"premium"}}"""
        val freeJson = """{"entitlement":{"is_premium":false,"plan":"free"}}"""
        assertTrue(SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(premiumJson))
        assertFalse(SubscriptionEntitlementParser.isPremiumFromSubscriptionJson(freeJson))
    }

    @Test
    fun entitlementJson_missingEntitlement_isFree() {
        assertFalse(SubscriptionEntitlementParser.isPremiumFromSubscriptionJson("""{"status":"inactive"}"""))
    }
}
