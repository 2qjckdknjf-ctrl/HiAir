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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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
    PARTIAL,
    REVOKING,
    REMOTE_REVOKE_PENDING,
    REVOKE_FAILED,
}

class HealthConnectService(
    private val context: Context,
    cleanupApiOverride: WearableCleanupApi? = null,
) {
    private val apiClient = ApiClient(AppConfig.apiBaseUrl)
    private val consentPrefs = context.getSharedPreferences(CONSENT_PREFS, Context.MODE_PRIVATE)
    private val cleanupApi: WearableCleanupApi = cleanupApiOverride ?: object : WearableCleanupApi {
        override fun deleteHealthData(userId: String, accessToken: String?): String {
            return apiClient.deleteHealthData(userId, accessToken)
        }

        override fun deleteWearableData(userId: String, accessToken: String?): String {
            return apiClient.deleteWearableData(userId, accessToken)
        }

        override fun revokeWearableConsent(userId: String, accessToken: String?): String {
            return apiClient.revokeWearableConsent(userId, accessToken)
        }
    }
    private val cleanupStore = object : CleanupProgressStore {
        override fun read(): CleanupProgress {
            return CleanupProgress(
                accountUserId = consentPrefs.getString(KEY_CLEANUP_ACCOUNT_USER_ID, "").orEmpty(),
                pending = consentPrefs.getBoolean(KEY_PENDING_REMOTE_CLEANUP, false),
                locallyRevoked = consentPrefs.getBoolean(KEY_LOCALLY_REVOKED, false),
                deleteDataRequested = consentPrefs.getBoolean(KEY_CLEANUP_DELETE_DATA, false),
                healthDeleteDone = consentPrefs.getBoolean(KEY_CLEANUP_HEALTH_DONE, false),
                wearableDeleteDone = consentPrefs.getBoolean(KEY_CLEANUP_WEARABLE_DONE, false),
                consentRevokeDone = consentPrefs.getBoolean(KEY_CLEANUP_REVOKE_DONE, false),
                lastErrorCategory = consentPrefs.getString(KEY_CLEANUP_ERROR_CATEGORY, null),
            )
        }

        override fun write(progress: CleanupProgress) {
            pendingRemoteCleanup = progress.pending
            locallyRevoked = progress.locallyRevoked
            lastConsentError = progress.lastErrorCategory
            // Active consent is never restored by a tombstone write.
            if (progress.hasPendingTombstone() || progress.locallyRevoked) {
                hasDurableConsent = false
            }
            lastConnectionState = when {
                progress.hasPendingTombstone() &&
                    (consentUserId.isBlank() || consentUserId == progress.accountUserId) ->
                    WearableConnectionState.REMOTE_REVOKE_PENDING
                progress.locallyRevoked && !progress.pending -> WearableConnectionState.NOT_CONNECTED
                else -> lastConnectionState
            }
            val editor = consentPrefs.edit()
                .putBoolean(KEY_PENDING_REMOTE_CLEANUP, progress.pending)
                .putBoolean(KEY_LOCALLY_REVOKED, progress.locallyRevoked)
                .putBoolean(KEY_CLEANUP_DELETE_DATA, progress.deleteDataRequested)
                .putBoolean(KEY_CLEANUP_HEALTH_DONE, progress.healthDeleteDone)
                .putBoolean(KEY_CLEANUP_WEARABLE_DONE, progress.wearableDeleteDone)
                .putBoolean(KEY_CLEANUP_REVOKE_DONE, progress.consentRevokeDone)
            if (progress.accountUserId.isBlank()) {
                editor.remove(KEY_CLEANUP_ACCOUNT_USER_ID)
            } else {
                editor.putString(KEY_CLEANUP_ACCOUNT_USER_ID, progress.accountUserId)
            }
            if (progress.lastErrorCategory.isNullOrBlank()) {
                editor.remove(KEY_CLEANUP_ERROR_CATEGORY)
            } else {
                editor.putString(KEY_CLEANUP_ERROR_CATEGORY, progress.lastErrorCategory)
            }
            // Successful cleanup clears tombstone account id; do not wipe active consent user here
            // unless this write is finishing a revoke for the active account.
            if (!progress.pending && progress.locallyRevoked && progress.accountUserId.isBlank()) {
                hasDurableConsent = false
                consentUserId = ""
                editor.putBoolean(KEY_DURABLE_CONSENT, false).remove(KEY_CONSENT_USER_ID)
            } else if (progress.hasPendingTombstone()) {
                editor.putBoolean(KEY_DURABLE_CONSENT, false)
            }
            editor.commit()
        }

        override fun onLocalRevokeStarted() {
            bumpSyncGeneration()
            hasDurableConsent = false
            lastConnectionState = WearableConnectionState.REVOKING
            consentPrefs.edit().putBoolean(KEY_DURABLE_CONSENT, false).commit()
        }
    }
    private val remoteCleanup = WearableRemoteCleanup(cleanupApi, cleanupStore)
    private val sessionCoordinator = WearableConsentSessionCoordinator(
        cleanup = remoteCleanup,
        store = cleanupStore,
        onActiveConsentCleared = {
            bumpSyncGeneration()
            hasDurableConsent = false
            consentUserId = ""
            lastConsentError = cleanupStore.read().lastErrorCategory
            // Preserve tombstone volatiles from durable store.
            val tombstone = cleanupStore.read()
            pendingRemoteCleanup = tombstone.pending
            locallyRevoked = tombstone.locallyRevoked || tombstone.hasPendingTombstone()
            lastConnectionState = when {
                tombstone.hasPendingTombstone() -> WearableConnectionState.REMOTE_REVOKE_PENDING
                else -> WearableConnectionState.NOT_CONNECTED
            }
            consentPrefs.edit()
                .putBoolean(KEY_DURABLE_CONSENT, false)
                .remove(KEY_CONSENT_USER_ID)
                .commit()
            // Intentionally do NOT clear KEY_PENDING_* / KEY_CLEANUP_* tombstone keys.
        },
        onConsentPersisted = { userId ->
            hasDurableConsent = true
            consentUserId = userId
            locallyRevoked = false
            // pendingRemoteCleanup stays true only if another account's tombstone exists;
            // for this account it must be clear (canGrantConsent already enforced).
            val tombstone = cleanupStore.read()
            pendingRemoteCleanup = tombstone.hasPendingTombstone() && tombstone.accountUserId != userId
            lastConsentError = null
            lastConnectionState = WearableConnectionState.CONNECTED
            consentPrefs.edit()
                .putBoolean(KEY_DURABLE_CONSENT, true)
                .putString(KEY_CONSENT_USER_ID, userId)
                .putBoolean(KEY_LOCALLY_REVOKED, false)
                .commit()
        },
        readConsentUserId = { consentUserId },
        readHasDurableConsent = { hasDurableConsent },
    )

    /** True only after successful backend consent for `consentUserId`. */
    @Volatile
    var hasDurableConsent: Boolean = false
        private set

    @Volatile
    var consentUserId: String = ""
        private set

    @Volatile
    var lastConsentError: String? = null
        private set

    @Volatile
    var lastConnectionState: WearableConnectionState = WearableConnectionState.NOT_CONNECTED
        private set

    /** Durable local revoke — survives process restart and blocks uploads even if remote cleanup failed. */
    @Volatile
    var locallyRevoked: Boolean = false
        private set

    /** Remote revoke/delete still needs retry; uploads remain blocked. */
    @Volatile
    var pendingRemoteCleanup: Boolean = false
        private set

    @Volatile
    var accountGeneration: Long = 0L
        private set

    @Volatile
    var syncGeneration: Long = 0L
        private set

    @Volatile
    var lastUploadBlockReason: HealthUploadGate.BlockReason? = null
        private set

    init {
        consentUserId = consentPrefs.getString(KEY_CONSENT_USER_ID, "").orEmpty()
        val tombstoneAccount = consentPrefs.getString(KEY_CLEANUP_ACCOUNT_USER_ID, "").orEmpty()
        locallyRevoked = consentPrefs.getBoolean(KEY_LOCALLY_REVOKED, false)
        pendingRemoteCleanup = consentPrefs.getBoolean(KEY_PENDING_REMOTE_CLEANUP, false)
        accountGeneration = consentPrefs.getLong(KEY_ACCOUNT_GENERATION, 0L)
        syncGeneration = consentPrefs.getLong(KEY_SYNC_GENERATION, 0L)
        val storedConsent = consentPrefs.getBoolean(KEY_DURABLE_CONSENT, false) && consentUserId.isNotBlank()
        val pendingDeleteBlocks =
            pendingRemoteCleanup &&
                tombstoneAccount.isNotBlank() &&
                tombstoneAccount == consentUserId &&
                consentPrefs.getBoolean(KEY_CLEANUP_DELETE_DATA, false)
        hasDurableConsent = storedConsent && !locallyRevoked && !pendingDeleteBlocks
        lastConsentError = consentPrefs.getString(KEY_CLEANUP_ERROR_CATEGORY, null)
        lastConnectionState = when {
            pendingRemoteCleanup && (consentUserId.isBlank() || consentUserId == tombstoneAccount) ->
                WearableConnectionState.REMOTE_REVOKE_PENDING
            hasDurableConsent -> WearableConnectionState.CONNECTED
            else -> WearableConnectionState.NOT_CONNECTED
        }
    }

    fun hasDurableConsentFor(userId: String): Boolean {
        if (userId.isBlank()) return false
        if (cleanupStore.read().blocksConsentFor(userId) || cleanupStore.read().blocksUploadsFor(userId)) {
            return false
        }
        return hasDurableConsent &&
            !locallyRevoked &&
            userId == consentUserId
    }

    fun bindAccountGeneration(generation: Long) {
        accountGeneration = generation
        consentPrefs.edit().putLong(KEY_ACCOUNT_GENERATION, generation).apply()
    }

    fun bumpSyncGeneration(): Long {
        val next = syncGeneration + 1L
        syncGeneration = next
        consentPrefs.edit().putLong(KEY_SYNC_GENERATION, next).commit()
        return next
    }

    fun markConsentPersisted(userId: String) {
        if (userId.isBlank()) {
            clearConsentSession()
            return
        }
        if (!sessionCoordinator.tryMarkConsentPersisted(userId)) {
            markConsentFailed("cleanup_pending_blocks_consent")
            return
        }
    }

    fun markConsentFailed(message: String) {
        hasDurableConsent = false
        consentUserId = ""
        lastConsentError = message
        lastConnectionState = WearableConnectionState.SYNC_FAILED
        consentPrefs.edit()
            .putBoolean(KEY_DURABLE_CONSENT, false)
            .remove(KEY_CONSENT_USER_ID)
            .apply()
    }

    /**
     * Clears active consent/session only. Account-bound cleanup tombstone is preserved
     * so logout/account switch cannot drop a pending delete.
     */
    fun clearConsentSession() {
        sessionCoordinator.clearActiveConsentPreservingTombstone()
    }

    /**
     * Local-first revoke: immediately blocks uploads and persists an account-bound tombstone.
     */
    fun markConsentRevokedLocally(userId: String, deleteData: Boolean = false) {
        val resolvedUserId = userId.ifBlank { cleanupStore.read().accountUserId }
        if (resolvedUserId.isBlank()) return
        sessionCoordinator.beginRevoke(accountUserId = resolvedUserId, deleteData = deleteData)
        val progress = cleanupStore.read()
        pendingRemoteCleanup = progress.pending
        locallyRevoked = progress.locallyRevoked
        hasDurableConsent = false
        consentUserId = ""
    }

    fun markRemoteCleanupSucceeded() {
        cleanupStore.write(
            CleanupProgress(
                accountUserId = "",
                pending = false,
                locallyRevoked = true,
                deleteDataRequested = false,
                healthDeleteDone = false,
                wearableDeleteDone = false,
                consentRevokeDone = true,
                lastErrorCategory = null,
            )
        )
        hasDurableConsent = false
        consentUserId = ""
        pendingRemoteCleanup = false
        locallyRevoked = true
        lastConnectionState = WearableConnectionState.NOT_CONNECTED
    }

    fun markRemoteCleanupFailed(message: String) {
        val current = cleanupStore.read()
        cleanupStore.write(
            current.copy(
                pending = true,
                locallyRevoked = true,
                lastErrorCategory = message,
            )
        )
        hasDurableConsent = false
        lastConnectionState = WearableConnectionState.REMOTE_REVOKE_PENDING
    }

    fun markConsentRevoked() {
        val userId = consentUserId.ifBlank { cleanupStore.read().accountUserId }
        markConsentRevokedLocally(userId = userId, deleteData = false)
        markRemoteCleanupSucceeded()
    }

    /** Durable delete-vs-revoke intent surviving restart / logout. */
    fun pendingCleanupDeletesData(): Boolean = cleanupStore.read().deleteDataRequested

    fun cleanupProgressSnapshot(): CleanupProgress = cleanupStore.read()

    fun pendingCleanupAccountUserId(): String = cleanupStore.read().accountUserId

    fun hasPendingCleanupTombstone(): Boolean = cleanupStore.read().hasPendingTombstone()

    fun uploadGateSnapshot(userId: String): HealthUploadGate.Snapshot {
        val tombstone = cleanupStore.read()
        val pendingForUser = tombstone.blocksUploadsFor(userId)
        return HealthUploadGate.Snapshot(
            userId = userId,
            accountGeneration = accountGeneration,
            syncGeneration = syncGeneration,
            hasDurableConsent = hasDurableConsent,
            consentUserId = consentUserId,
            locallyRevoked = pendingForUser || (locallyRevoked && (consentUserId.isBlank() || consentUserId == userId)),
            pendingRemoteCleanup = pendingForUser,
        )
    }

    fun ensureUploadAllowed(
        userId: String,
        expectedAccountGeneration: Long,
        expectedSyncGeneration: Long,
    ) {
        val reason = HealthUploadGate.assertAllowed(
            expectedUserId = userId,
            expectedAccountGeneration = expectedAccountGeneration,
            expectedSyncGeneration = expectedSyncGeneration,
            snapshot = uploadGateSnapshot(userId),
        )
        lastUploadBlockReason = reason
        if (reason != null) {
            throw IllegalStateException("health_upload_blocked:$reason")
        }
    }

    companion object {
        private const val CONSENT_PREFS = "hiair_wearable_consent"
        private const val KEY_DURABLE_CONSENT = "durable_consent"
        private const val KEY_CONSENT_USER_ID = "consent_user_id"
        private const val KEY_LOCALLY_REVOKED = "locally_revoked"
        private const val KEY_PENDING_REMOTE_CLEANUP = "pending_remote_cleanup"
        private const val KEY_CLEANUP_ACCOUNT_USER_ID = "cleanup_account_user_id"
        private const val KEY_CLEANUP_DELETE_DATA = "cleanup_delete_data"
        private const val KEY_CLEANUP_HEALTH_DONE = "cleanup_health_done"
        private const val KEY_CLEANUP_WEARABLE_DONE = "cleanup_wearable_done"
        private const val KEY_CLEANUP_REVOKE_DONE = "cleanup_revoke_done"
        private const val KEY_CLEANUP_ERROR_CATEGORY = "cleanup_error_category"
        private const val KEY_ACCOUNT_GENERATION = "account_generation"
        private const val KEY_SYNC_GENERATION = "sync_generation"
    }

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

    suspend fun saveConsent(userId: String, accessToken: String?): String = withContext(Dispatchers.IO) {
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
        apiClient.saveWearableConsent(userId, accessToken, payload.toString())
    }

    suspend fun syncWearableDailySummary(userId: String, accessToken: String?): WearableConnectionState {
        return syncHealthIntelligence(userId, accessToken, profileId = null)
    }

    suspend fun syncHealthIntelligence(
        userId: String,
        accessToken: String?,
        profileId: String?,
        expectedAccountGeneration: Long = accountGeneration,
        expectedSyncGeneration: Long = syncGeneration,
    ): WearableConnectionState {
        return try {
            if (!isHealthConnectAvailable()) return WearableConnectionState.UNAVAILABLE
            if (!hasDurableConsentFor(userId)) return WearableConnectionState.NOT_CONNECTED
            ensureUploadAllowed(userId, expectedAccountGeneration, expectedSyncGeneration)

            val granted = grantedPermissions()
            val metrics = JSONArray()
            appendAggregateMetric(metrics, "steps", "count", "steps")
            appendAggregateMetric(metrics, "distance_walking_running", "m", "distance", meters = true)
            appendAggregateMetric(metrics, "active_energy", "kcal", "active_energy")
            appendAggregateMetric(metrics, "basal_energy", "kcal", "total_energy")
            appendAggregateMetric(metrics, "flights_climbed", "count", "floors")

            val hr = if (granted.containsAll(tier2Permissions)) {
                fetchHeartRateSummary()
            } else {
                Triple(null, null, null)
            }
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
            } else if (!granted.containsAll(tier2Permissions)) {
                metrics.put(emptyMetric("heart_rate", "bpm", "permission_denied"))
            } else {
                metrics.put(emptyMetric("heart_rate", "bpm"))
            }

            val resting = if (granted.containsAll(tier2Permissions)) fetchRestingHeartRate() else null
            metrics.put(
                when {
                    resting != null -> metricJson("resting_heart_rate", "bpm", avg = resting, latest = resting, sampleCount = 1)
                    !granted.containsAll(tier2Permissions) -> emptyMetric("resting_heart_rate", "bpm", "permission_denied")
                    else -> emptyMetric("resting_heart_rate", "bpm")
                }
            )

            if (granted.containsAll(tier2Permissions)) {
                appendHrv(metrics)
                appendVo2(metrics)
            } else {
                metrics.put(emptyMetric("hrv_rmssd", "ms", "permission_denied"))
                metrics.put(emptyMetric("vo2_max", "ml_kg_min", "permission_denied"))
            }
            if (granted.containsAll(tier3Permissions)) {
                appendRespiratory(metrics)
                appendOxygen(metrics)
                appendBodyTemperature(metrics)
            } else {
                metrics.put(emptyMetric("respiratory_rate", "breaths_per_min", "permission_denied"))
                metrics.put(emptyMetric("oxygen_saturation", "percent", "permission_denied"))
                metrics.put(emptyMetric("body_temperature", "celsius", "permission_denied"))
            }
            appendWorkouts(metrics)
            val sleep = buildSleepJson()

            // Re-check immediately before first upload (revoke may have raced during collection).
            ensureUploadAllowed(userId, expectedAccountGeneration, expectedSyncGeneration)

            val localDate = LocalDate.now().toString()
            val payload = JSONObject()
                .put("profileId", profileId)
                .put("localDate", localDate)
                .put("timezone", ZoneId.systemDefault().id)
                .put("platform", "android")
                .put("source", "health_connect")
                .put("clientSyncVersion", "health-intelligence-v1")
                .put("idempotencyKey", "android-$localDate-${Instant.now().epochSecond / 300}")
                .put("metrics", metrics)
                .put("sleep", sleep)
                .put("cursorMetadata", JSONObject().put("mode", "foreground_daily"))

            withContext(Dispatchers.IO) {
                ensureUploadAllowed(userId, expectedAccountGeneration, expectedSyncGeneration)
                apiClient.syncHealthData(userId, accessToken, payload.toString())

                // Re-check between uploads.
                ensureUploadAllowed(userId, expectedAccountGeneration, expectedSyncGeneration)

                var stepsTotal: Long? = null
                for (i in 0 until metrics.length()) {
                    val row = metrics.optJSONObject(i) ?: continue
                    if (row.optString("metricType") == "steps" && !row.isNull("valueTotal")) {
                        stepsTotal = row.optDouble("valueTotal").toLong()
                        break
                    }
                }
                val legacy = JSONObject()
                    .put("date", localDate)
                    .put("stepsTotal", stepsTotal)
                    .put("heartRateAvg", hr.first)
                    .put("heartRateMin", hr.second)
                    .put("heartRateMax", hr.third)
                    .put("restingHeartRateAvg", resting)
                    .put("source", "health_connect")
                apiClient.uploadWearableDailySummary(userId, accessToken, legacy.toString())
            }

            WearableConnectionState.CONNECTED
        } catch (_: SecurityException) {
            WearableConnectionState.PERMISSION_DENIED
        } catch (blocked: IllegalStateException) {
            if (blocked.message?.startsWith("health_upload_blocked:") == true) {
                WearableConnectionState.NOT_CONNECTED
            } else {
                WearableConnectionState.SYNC_FAILED
            }
        } catch (_: Exception) {
            WearableConnectionState.SYNC_FAILED
        }
    }

    suspend fun fetchWearableToday(userId: String, accessToken: String?): String = withContext(Dispatchers.IO) {
        apiClient.fetchWearableToday(userId, accessToken)
    }

    suspend fun deleteHealthData(userId: String, accessToken: String?): String = withContext(Dispatchers.IO) {
        // Prefer atomic orchestrator for delete+revoke; keep direct deletes for rare callers.
        cleanupApi.deleteHealthData(userId, accessToken)
        cleanupApi.deleteWearableData(userId, accessToken)
    }

    suspend fun revokeConsent(userId: String, accessToken: String?): String = withContext(Dispatchers.IO) {
        cleanupApi.revokeWearableConsent(userId, accessToken)
    }

    /**
     * Production remote cleanup path: delete (optional) + revoke, fail-closed on any non-2xx / timeout.
     * Account isolation: only runs when [userId] matches the durable tombstone account.
     */
    suspend fun performRemoteCleanup(userId: String, accessToken: String?): Boolean = withContext(Dispatchers.IO) {
        val result = sessionCoordinator.runCleanupForAuthenticatedUser(userId, accessToken)
        val progress = result.progress
        pendingRemoteCleanup = progress.pending
        locallyRevoked = progress.locallyRevoked || progress.hasPendingTombstone()
        if (result.remoteCleanupSucceeded) {
            hasDurableConsent = false
            consentUserId = ""
        }
        result.remoteCleanupSucceeded
    }

    /**
     * Retry remote revoke/delete without re-enabling uploads.
     * No-op when tombstone belongs to a different account (never uses token B for user A).
     */
    suspend fun retryRemoteCleanup(userId: String, accessToken: String?, deleteData: Boolean = false): Boolean {
        val tombstone = cleanupStore.read()
        if (tombstone.hasPendingTombstone() && tombstone.accountUserId != userId) {
            return false
        }
        if (deleteData && tombstone.hasPendingTombstone() && tombstone.accountUserId == userId && !tombstone.deleteDataRequested) {
            sessionCoordinator.beginRevoke(accountUserId = userId, deleteData = true)
        }
        if (!tombstone.hasPendingTombstone() && tombstone.isRemoteFullyComplete()) {
            return true
        }
        if (!tombstone.hasPendingTombstone() && !tombstone.locallyRevoked) return true
        return performRemoteCleanup(userId, accessToken)
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
