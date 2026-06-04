package com.hiair.billing

/**
 * JVM-friendly parser for subscription `/me` JSON (no android.org.json in unit tests).
 */
object SubscriptionEntitlementParser {
    private val PREMIUM_TRUE = Regex(""""is_premium"\s*:\s*true""", RegexOption.IGNORE_CASE)

    fun isPremiumFromSubscriptionJson(raw: String): Boolean {
        return PREMIUM_TRUE.containsMatchIn(raw)
    }
}
