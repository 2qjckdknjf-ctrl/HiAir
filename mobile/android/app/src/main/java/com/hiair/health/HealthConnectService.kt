package com.hiair.health

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.hiair.network.ApiClient
import com.hiair.network.AppConfig
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

enum class WearableConnectionState {
    NOT_CONNECTED,
    PERMISSION_REQUIRED,
    CONNECTED,
    PERMISSION_DENIED,
    DATA_UNAVAILABLE,
    SYNC_FAILED,
    UNAVAILABLE,
    PARTIAL
}

class HealthConnectService(private val context: Context) {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)

    val tier1Permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getReadPermission(DistanceRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(FloorsClimbedRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getReadPermission(SleepSessionRecord::class),
    )

    val tier2Permissions = setOf(
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(RestingHeartRateRecord::class),
        HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
        HealthPermission.getReadPermission(Vo2MaxRecord::class),
    )

    val tier3Permissions = setOf(
        HealthPermission.getReadPermission(RespiratoryRateRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getReadPermission(BodyTemperatureRecord::class),
    )

    val readPermissions: Set<String>
        get() = tier1Permissions + tier2Permissions + tier3Permissions

    suspend fun hasAllPermissions(): Boolean {
        if (!isHealthConnectAvailable()) return false
        val client = HealthConnectClient.getOrCreate(context)
        return client.permissionController.getGrantedPermissions().containsAll(readPermissions)
    }

    suspend fun grantedPermissions(): Set<String> {
        if (!isHealthConnectAvailable()) return emptySet()
        return HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions()
    }

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

    suspend fun fetchTodaySteps(): Long? = aggregateLong()

    suspend fun fetchHeartRateSummary(): Triple<Double?, Double?, Double?> {
        if (!isHealthConnectAvailable()) return Triple(null, null, null)
        val client = HealthConnectClient.getOrCreate(context)
        val (start, end) = todayRange()
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
            .put("hrvEnabled", true)
            .put("sleepEnabled", true)
            .put("activityEnabled", true)
            .put("sleepStagesEnabled", true)
            .put("respiratoryEnabled", true)
            .put("temperatureEnabled", true)
            .put("workoutsEnabled", true)
            .put("fitnessEnabled", true)
            .put("bodyMetricsEnabled", false)
            .put("sensitiveMetricsEnabled", false)
            .put("consentVersion", "health-intelligence-v1")
        return apiClient.saveWearableConsent(userId, accessToken, payload.toString())
    }

    suspend fun syncWearableDailySummary(userId: String, accessToken: String?): WearableConnectionState {
        return syncHealthIntelligence(userId, accessToken, profileId = null)
    }

    suspend fun syncHealthIntelligence(
        userId: String,
        accessToken: String?,
        profileId: String?,
    ): WearableConnectionState {
        return try {
            if (!isHealthConnectAvailable()) return WearableConnectionState.UNAVAILABLE
            val metrics = JSONArray()
            appendAggregateMetric(metrics, "steps", "count", "steps")
            appendAggregateMetric(metrics, "distance_walking_running", "m", "distance", meters = true)
            appendAggregateMetric(metrics, "active_energy", "kcal", "active_energy")
            appendAggregateMetric(metrics, "basal_energy", "kcal", "total_energy")
            appendAggregateMetric(metrics, "flights_climbed", "count", "floors")

            val hr = fetchHeartRateSummary()
            if (hr.first != null || hr.second != null || hr.third != null) {
                metrics.put(
                    metricJson(
                        type = "heart_rate",
                        unit = "bpm",
                        avg = hr.first,
                        min = hr.second,
                        max = hr.third,
                        sampleCount = 1,
                    )
                )
            } else {
                metrics.put(emptyMetric("heart_rate", "bpm"))
            }

            val resting = fetchRestingHeartRate()
            metrics.put(
                if (resting != null) {
                    metricJson("resting_heart_rate", "bpm", avg = resting, latest = resting, sampleCount = 1)
                } else {
                    emptyMetric("resting_heart_rate", "bpm")
                }
            )

            appendHrv(metrics)
            appendRespiratory(metrics)
            appendOxygen(metrics)
            appendBodyTemperature(metrics)
            appendVo2(metrics)
            appendWorkouts(metrics)
            val sleep = buildSleepJson()

            val localDate = LocalDate.now().toString()
            val payload = JSONObject()
                .put("profileId", profileId)
                .put("localDate", localDate)
                .put("timezone", ZoneId.systemDefault().id)
                .put("platform", "android")
                .put("source", "health_connect")
                .put("clientSyncVersion", "health-intelligence-v1")
                .put("idempotencyKey", "android-$localDate-${UUID.randomUUID()}")
                .put("metrics", metrics)
                .put("sleep", sleep)
                .put("cursorMetadata", JSONObject().put("mode", "foreground_daily"))

            apiClient.syncHealthData(userId, accessToken, payload.toString())

            // Legacy daily for personalLoad
            val legacy = JSONObject()
                .put("date", localDate)
                .put("stepsTotal", fetchTodaySteps())
                .put("heartRateAvg", hr.first)
                .put("heartRateMin", hr.second)
                .put("heartRateMax", hr.third)
                .put("restingHeartRateAvg", resting)
                .put("source", "health_connect")
            apiClient.uploadWearableDailySummary(userId, accessToken, legacy.toString())

            WearableConnectionState.CONNECTED
        } catch (_: SecurityException) {
            WearableConnectionState.PERMISSION_DENIED
        } catch (_: Exception) {
            WearableConnectionState.SYNC_FAILED
        }
    }

    fun fetchWearableToday(userId: String, accessToken: String?): String {
        return apiClient.fetchWearableToday(userId, accessToken)
    }

    fun deleteHealthData(userId: String, accessToken: String?): String {
        apiClient.deleteHealthData(userId, accessToken)
        return apiClient.deleteWearableData(userId, accessToken)
    }

    fun revokeConsent(userId: String, accessToken: String?): String {
        return apiClient.revokeWearableConsent(userId, accessToken)
    }

    private suspend fun aggregateLong(): Long? {
        if (!isHealthConnectAvailable()) return null
        val client = HealthConnectClient.getOrCreate(context)
        val (start, end) = todayRange()
        val response = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end),
            )
        )
        return response[StepsRecord.COUNT_TOTAL]
    }

    private suspend fun appendAggregateMetric(
        metrics: JSONArray,
        type: String,
        unit: String,
        metricKey: String,
        meters: Boolean = false,
    ) {
        try {
            if (!isHealthConnectAvailable()) {
                metrics.put(emptyMetric(type, unit, "source_unavailable"))
                return
            }
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val number: Double? = when (metricKey) {
                "steps" -> client.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )[StepsRecord.COUNT_TOTAL]?.toDouble()
                "distance" -> client.aggregate(
                    AggregateRequest(
                        metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )[DistanceRecord.DISTANCE_TOTAL]?.inMeters
                "active_energy" -> client.aggregate(
                    AggregateRequest(
                        metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories
                "total_energy" -> client.aggregate(
                    AggregateRequest(
                        metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories
                "floors" -> client.aggregate(
                    AggregateRequest(
                        metrics = setOf(FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL]
                else -> null
            }
            if (number == null) {
                metrics.put(emptyMetric(type, unit))
                return
            }
            metrics.put(metricJson(type, unit, total = number, sampleCount = 1))
        } catch (_: SecurityException) {
            metrics.put(emptyMetric(type, unit, "permission_denied"))
        } catch (_: Exception) {
            metrics.put(emptyMetric(type, unit, "sync_error"))
        }
    }

    private suspend fun appendHrv(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (records.isEmpty()) {
                metrics.put(emptyMetric("hrv_rmssd", "ms"))
                return
            }
            val values = records.map { it.heartRateVariabilityMillis }
            metrics.put(
                metricJson(
                    type = "hrv_rmssd",
                    unit = "ms",
                    avg = values.average(),
                    min = values.minOrNull(),
                    max = values.maxOrNull(),
                    sampleCount = values.size,
                ).put("hrvMethod", "rmssd")
            )
        } catch (_: SecurityException) {
            metrics.put(emptyMetric("hrv_rmssd", "ms", "permission_denied"))
        } catch (_: Exception) {
            metrics.put(emptyMetric("hrv_rmssd", "ms", "sync_error"))
        }
    }

    private suspend fun appendRespiratory(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = RespiratoryRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (records.isEmpty()) {
                metrics.put(emptyMetric("respiratory_rate", "breaths_per_min"))
                return
            }
            val values = records.map { it.rate }
            metrics.put(
                metricJson(
                    "respiratory_rate",
                    "breaths_per_min",
                    avg = values.average(),
                    min = values.minOrNull(),
                    max = values.maxOrNull(),
                    latest = values.lastOrNull(),
                    sampleCount = values.size,
                )
            )
        } catch (_: SecurityException) {
            metrics.put(emptyMetric("respiratory_rate", "breaths_per_min", "permission_denied"))
        } catch (_: Exception) {
            metrics.put(emptyMetric("respiratory_rate", "breaths_per_min", "sync_error"))
        }
    }

    private suspend fun appendOxygen(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = OxygenSaturationRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (records.isEmpty()) {
                metrics.put(emptyMetric("oxygen_saturation", "percent"))
                return
            }
            val values = records.map { it.percentage.value }
            metrics.put(
                metricJson(
                    "oxygen_saturation",
                    "percent",
                    avg = values.average(),
                    min = values.minOrNull(),
                    max = values.maxOrNull(),
                    latest = values.lastOrNull(),
                    sampleCount = values.size,
                )
            )
        } catch (_: SecurityException) {
            metrics.put(emptyMetric("oxygen_saturation", "percent", "permission_denied"))
        } catch (_: Exception) {
            metrics.put(emptyMetric("oxygen_saturation", "percent", "sync_error"))
        }
    }

    private suspend fun appendBodyTemperature(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = BodyTemperatureRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (records.isEmpty()) {
                metrics.put(emptyMetric("body_temperature", "celsius"))
                return
            }
            val values = records.map { it.temperature.inCelsius }
            metrics.put(
                metricJson(
                    "body_temperature",
                    "celsius",
                    avg = values.average(),
                    min = values.minOrNull(),
                    max = values.maxOrNull(),
                    latest = values.lastOrNull(),
                    sampleCount = values.size,
                )
            )
        } catch (_: SecurityException) {
            metrics.put(emptyMetric("body_temperature", "celsius", "permission_denied"))
        } catch (_: Exception) {
            metrics.put(emptyMetric("body_temperature", "celsius", "sync_error"))
        }
    }

    private suspend fun appendVo2(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val start = LocalDate.now().minusDays(90).atStartOfDay(ZoneId.systemDefault()).toInstant()
            val end = Instant.now()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = Vo2MaxRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            val latest = records.lastOrNull()?.vo2MillilitersPerMinuteKilogram
            if (latest == null) {
                metrics.put(emptyMetric("vo2_max", "ml_kg_min"))
            } else {
                metrics.put(metricJson("vo2_max", "ml_kg_min", latest = latest, avg = latest, sampleCount = 1))
            }
        } catch (_: Exception) {
            metrics.put(emptyMetric("vo2_max", "ml_kg_min", "sync_error"))
        }
    }

    private suspend fun appendWorkouts(metrics: JSONArray) {
        try {
            val client = HealthConnectClient.getOrCreate(context)
            val (start, end) = todayRange()
            val records = client.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (records.isEmpty()) {
                metrics.put(emptyMetric("workout_count", "count"))
                return
            }
            val durationMin = records.sumOf {
                java.time.Duration.between(it.startTime, it.endTime).toMinutes().toDouble()
            }
            metrics.put(metricJson("workout_count", "count", total = records.size.toDouble(), sampleCount = records.size))
            metrics.put(metricJson("workout_duration", "min", total = durationMin, sampleCount = records.size))
            metrics.put(metricJson("exercise_minutes", "min", total = durationMin, sampleCount = records.size))
        } catch (_: Exception) {
            metrics.put(emptyMetric("workout_count", "count", "sync_error"))
        }
    }

    private suspend fun buildSleepJson(): JSONObject {
        val localDate = LocalDate.now().toString()
        return try {
            val client = HealthConnectClient.getOrCreate(context)
            val start = LocalDate.now().minusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant()
            val end = Instant.now()
            val sessions = client.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                )
            ).records
            if (sessions.isEmpty()) {
                return JSONObject()
                    .put("localDate", localDate)
                    .put("qualityState", "no_records")
            }
            var awake = 0L
            var light = 0L
            var deep = 0L
            var rem = 0L
            var total = 0L
            var sleepStart: Instant? = null
            var sleepEnd: Instant? = null
            for (session in sessions) {
                sleepStart = minInstant(sleepStart, session.startTime)
                sleepEnd = maxInstant(sleepEnd, session.endTime)
                total += java.time.Duration.between(session.startTime, session.endTime).toMinutes()
                for (stage in session.stages) {
                    val minutes = java.time.Duration.between(stage.startTime, stage.endTime).toMinutes()
                    when (stage.stage) {
                        SleepSessionRecord.STAGE_TYPE_AWAKE,
                        SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED,
                        SleepSessionRecord.STAGE_TYPE_OUT_OF_BED,
                        -> awake += minutes
                        SleepSessionRecord.STAGE_TYPE_LIGHT,
                        SleepSessionRecord.STAGE_TYPE_SLEEPING,
                        SleepSessionRecord.STAGE_TYPE_UNKNOWN,
                        -> light += minutes
                        SleepSessionRecord.STAGE_TYPE_DEEP -> deep += minutes
                        SleepSessionRecord.STAGE_TYPE_REM -> rem += minutes
                    }
                }
            }
            val asleep = light + deep + rem
            val quality = if (deep > 0 || rem > 0) "ok" else if (asleep > 0 || total > 0) "partial" else "no_records"
            JSONObject()
                .put("localDate", localDate)
                .put("totalMinutes", if (asleep > 0) asleep else total)
                .put("inBedMinutes", total)
                .put("awakeMinutes", awake.takeIf { it > 0 })
                .put("coreLightMinutes", light.takeIf { it > 0 })
                .put("deepMinutes", deep.takeIf { it > 0 })
                .put("remMinutes", rem.takeIf { it > 0 })
                .put("sleepStart", sleepStart?.toString())
                .put("sleepEnd", sleepEnd?.toString())
                .put("qualityState", quality)
        } catch (_: SecurityException) {
            JSONObject().put("localDate", localDate).put("qualityState", "permission_denied")
        } catch (_: Exception) {
            JSONObject().put("localDate", localDate).put("qualityState", "sync_error")
        }
    }

    private fun todayRange(): Pair<Instant, Instant> {
        val start = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant()
        return start to Instant.now()
    }

    private fun metricJson(
        type: String,
        unit: String,
        avg: Double? = null,
        min: Double? = null,
        max: Double? = null,
        latest: Double? = null,
        total: Double? = null,
        sampleCount: Int = 0,
        quality: String = "ok",
    ): JSONObject {
        return JSONObject()
            .put("metricType", type)
            .put("unit", unit)
            .put("valueAvg", avg)
            .put("valueMin", min)
            .put("valueMax", max)
            .put("valueLatest", latest)
            .put("valueTotal", total)
            .put("sampleCount", sampleCount)
            .put("qualityState", quality)
            .put("sourceDeviceClass", "phone_or_watch")
    }

    private fun emptyMetric(type: String, unit: String, quality: String = "no_records"): JSONObject {
        return metricJson(type, unit, sampleCount = 0, quality = quality)
    }

    private fun minInstant(a: Instant?, b: Instant): Instant = if (a == null || b.isBefore(a)) b else a
    private fun maxInstant(a: Instant?, b: Instant): Instant = if (a == null || b.isAfter(a)) b else a
}
