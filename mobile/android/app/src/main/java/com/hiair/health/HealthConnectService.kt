package com.hiair.health

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import org.json.JSONObject

enum class WearableConnectionState {
    NOT_CONNECTED,
    PERMISSION_REQUIRED,
    CONNECTED,
    PERMISSION_DENIED,
    DATA_UNAVAILABLE,
    SYNC_FAILED,
    UNAVAILABLE
}

class HealthConnectService(private val context: Context) {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)

    private val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
    )

    fun isHealthConnectAvailable(): Boolean {
        return HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    }

    fun healthConnectInstallIntent(): Intent? {
        if (isHealthConnectAvailable()) return null
        return Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("market://details?id=com.google.android.apps.healthdata")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    suspend fun requestPermissions(activity: androidx.activity.ComponentActivity): Boolean {
        if (!isHealthConnectAvailable()) return false
        val client = HealthConnectClient.getOrCreate(context)
        val granted = client.permissionController.getGrantedPermissions()
        return granted.containsAll(permissions)
    }

    suspend fun fetchTodaySteps(): Long? {
        if (!isHealthConnectAvailable()) return null
        val client = HealthConnectClient.getOrCreate(context)
        val start = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val end = Instant.now()
        val response = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end),
            )
        )
        return response[StepsRecord.COUNT_TOTAL]?.toLong()
    }

    suspend fun fetchHeartRateSummary(): Triple<Double?, Double?, Double?> {
        if (!isHealthConnectAvailable()) return Triple(null, null, null)
        val client = HealthConnectClient.getOrCreate(context)
        val start = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        val end = Instant.now()
        val records = client.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end),
            )
        ).records
        if (records.isEmpty()) return Triple(null, null, null)
        val values = records.flatMap { record -> record.samples.map { it.beatsPerMinute.toDouble() } }
        if (values.isEmpty()) return Triple(null, null, null)
        return Triple(values.average(), values.minOrNull(), values.maxOrNull())
    }

    suspend fun fetchRestingHeartRate(): Double? {
        if (!isHealthConnectAvailable()) return null
        val client = HealthConnectClient.getOrCreate(context)
        val start = LocalDate.now().minusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
        val end = Instant.now()
        val records = client.readRecords(
            ReadRecordsRequest(
                recordType = RestingHeartRateRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end),
            )
        ).records
        return records.lastOrNull()?.beatsPerMinute?.toDouble()
    }

    fun saveConsent(userId: String, accessToken: String?): String {
        val payload = JSONObject()
            .put("platform", "android")
            .put("source", "health_connect")
            .put("stepsEnabled", true)
            .put("heartRateEnabled", true)
            .put("restingHeartRateEnabled", true)
            .put("hrvEnabled", false)
            .put("sleepEnabled", false)
            .put("consentVersion", "wearables-v1")
        return apiClient.saveWearableConsent(userId, accessToken, payload.toString())
    }

    suspend fun syncWearableDailySummary(userId: String, accessToken: String?): WearableConnectionState {
        return try {
            val steps = fetchTodaySteps()
            val hr = fetchHeartRateSummary()
            val resting = fetchRestingHeartRate()
            val payload = JSONObject()
                .put("date", LocalDate.now().toString())
                .put("stepsTotal", steps)
                .put("heartRateAvg", hr.first)
                .put("heartRateMin", hr.second)
                .put("heartRateMax", hr.third)
                .put("restingHeartRateAvg", resting)
                .put("source", "health_connect")
            apiClient.uploadWearableDailySummary(userId, accessToken, payload.toString())
            WearableConnectionState.CONNECTED
        } catch (_: Exception) {
            WearableConnectionState.SYNC_FAILED
        }
    }

    fun fetchWearableToday(userId: String, accessToken: String?): String {
        return apiClient.fetchWearableToday(userId, accessToken)
    }

    fun deleteHealthData(userId: String, accessToken: String?): String {
        return apiClient.deleteWearableData(userId, accessToken)
    }

    fun revokeConsent(userId: String, accessToken: String?): String {
        return apiClient.revokeWearableConsent(userId, accessToken)
    }
}
