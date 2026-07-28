package com.hiair.health

/**
 * Network surface used by wearable remote cleanup.
 * Production wires [com.hiair.network.ApiClient]; tests inject fakes (no real network).
 */
interface WearableCleanupApi {
    fun deleteHealthData(userId: String, accessToken: String?): String

    fun deleteWearableData(userId: String, accessToken: String?): String

    fun revokeWearableConsent(userId: String, accessToken: String?): String
}
