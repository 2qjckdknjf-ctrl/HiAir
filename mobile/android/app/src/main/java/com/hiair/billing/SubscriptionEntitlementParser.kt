package com.hiair.billing

/**
 * JVM-friendly parser for subscription `/me` JSON (no android.org.json in unit tests).
 */
object SubscriptionEntitlementParser {
    private val PREMIUM_TRUE = Regex(""""is_premium"\s*:\s*true""", RegexOption.IGNORE_CASE)

    fun isPremiumFromSubscriptionJson(raw: String): Boolean {
        val entitlementBlock = extractEntitlementObject(raw) ?: return false
        return PREMIUM_TRUE.containsMatchIn(entitlementBlock)
    }

    internal fun extractEntitlementObject(raw: String): String? {
        val keyIndex = raw.indexOf("\"entitlement\"")
        if (keyIndex < 0) {
            return null
        }
        val braceStart = raw.indexOf('{', keyIndex)
        if (braceStart < 0) {
            return null
        }
        var depth = 0
        for (index in braceStart until raw.length) {
            when (raw[index]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) {
                        return raw.substring(braceStart, index + 1)
                    }
                }
            }
        }
        return null
    }
}
