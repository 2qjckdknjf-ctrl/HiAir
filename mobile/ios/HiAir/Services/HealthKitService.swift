import Foundation
import HealthKit
import UIKit

enum WearableConnectionState: String, Equatable {
    case notConnected
    case permissionRequested
    /// System HealthKit sheet completed; HiAir consent not yet durable.
    case systemAuthorized
    /// Backend consent persistence in progress.
    case consentSaving
    case consentFailed
    case connected
    /// Local consent revoked; remote revoke/delete in flight.
    case revoking
    /// Local consent cleared; waiting for remote revoke retry.
    case remoteRevokePending
    case revokeFailed
    case permissionDenied
    case dataUnavailable
    case syncFailed
    case unavailable
    case partial
}

enum HealthConsentTier: Int, CaseIterable {
    case activitySleep = 1
    case heartRecovery = 2
    case respiratoryTemperature = 3
    case extendedOptIn = 4
}

struct HealthKitDiagnostics: Equatable {
    let healthDataAvailable: Bool
    let shareUsageDescriptionPresent: Bool
    let updateUsageDescriptionPresent: Bool
    let readTypeCount: Int
    let buildNumber: String
}

struct HealthMetricSnapshot: Equatable, Sendable {
    let metricType: String
    let unit: String
    let valueAvg: Double?
    let valueMin: Double?
    let valueMax: Double?
    let valueLatest: Double?
    let valueTotal: Double?
    let sampleCount: Int
    let qualityState: String
    let hrvMethod: String?
}

struct HealthSleepSnapshot: Equatable, Sendable {
    let totalMinutes: Int?
    let inBedMinutes: Int?
    let awakeMinutes: Int?
    let coreLightMinutes: Int?
    let deepMinutes: Int?
    let remMinutes: Int?
    let sleepStart: Date?
    let sleepEnd: Date?
    let qualityState: String
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var connectionState: WearableConnectionState = .notConnected
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastAuthorizationError: String?
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var latestSnapshots: [HealthMetricSnapshot] = []
    @Published private(set) var latestSleep: HealthSleepSnapshot?
    @Published private(set) var enabledTiers: Set<Int> = [1]

    private let store = HKHealthStore()
    private let apiClient = APIClient.live()
    private let consentVersion = "health-intelligence-v1"
    private let defaults: UserDefaults
    private let tiersKey = "hiair.health.enabledTiers"
    private let anchorKeyPrefix = "hiair.health.anchor."
    private var authorizationInFlight: Task<Bool, Never>?
    private var syncInFlight: Task<Void, Never>?
    private var syncGeneration: UInt64 = 0
    /// Authenticated HiAir user that owns current connection/consent presentation state.
    private(set) var boundUserId: String = ""
    /// Overridable for unit tests (default 60s).
    var authorizationTimeoutNanoseconds: UInt64 = 60_000_000_000
    /// Overridable for unit tests (default 45s collect).
    var healthCollectTimeoutNanoseconds: UInt64 = 45_000_000_000
    /// Injectable sleeper for timeout races (tests use ImmediateNanosleeper).
    var timeoutSleeper: any Nanosleeping = SystemNanosleeper()
    /// Test seam: replace HealthKit collect (deterministic race tests).
    var testCollectHandler: (() async -> ([HealthMetricSnapshot], HealthSleepSnapshot?))?
    /// Test seam: run before each network upload (e.g. slow remote).
    var testBeforeUploadHook: (() async -> Void)?
    /// Test seam: replace remote revoke/delete network calls.
    var testRemoteRevokeHandler: (() async throws -> Void)?
    var testRemoteDeleteHandler: (() async throws -> Void)?
    /// Counts times the upload gate was reached (before hook / network).
    private(set) var testUploadGateReachedCount: Int = 0
    /// Counts upload attempts that passed the consent/generation gate after the hook.
    private(set) var testUploadAttemptCount: Int = 0
    var syncGenerationForTests: UInt64 { syncGeneration }
    var hasSyncInFlightForTests: Bool { syncInFlight != nil }

    private func authorizationCompletedKey(for userId: String) -> String {
        "hiair.health.authorizationCompleted.\(userId)"
    }

    private func consentPersistedKey(for userId: String) -> String {
        "hiair.health.consentPersisted.\(userId)"
    }

    func hasSystemAuthorization(for userId: String) -> Bool {
        !userId.isEmpty && defaults.bool(forKey: authorizationCompletedKey(for: userId))
    }

    func hasDurableConsent(for userId: String) -> Bool {
        !userId.isEmpty && defaults.bool(forKey: consentPersistedKey(for: userId))
    }

    /// Bind / rehydrate account-scoped Health presentation after login.
    func bindAccount(userId: String) {
        boundUserId = userId
        guard !userId.isEmpty else {
            connectionState = .notConnected
            return
        }
        if hasDurableConsent(for: userId) {
            connectionState = .connected
        } else if hasSystemAuthorization(for: userId) {
            connectionState = .systemAuthorized
        } else {
            connectionState = .notConnected
        }
    }

    /// Reconcile local durable consent from server truth (e.g. `/wearables/today`).
    func reconcileServerConsent(userId: String, isActive: Bool) {
        guard !userId.isEmpty else { return }
        guard boundUserId.isEmpty || boundUserId == userId else { return }
        if isActive {
            if !hasDurableConsent(for: userId) {
                ProductAnalytics.track("health_consent_rehydrated", properties: ["source": "server"])
            }
            markConsentPersisted(for: userId)
        } else {
            if hasDurableConsent(for: userId) {
                clearConsentPersisted(for: userId)
                ProductAnalytics.track("health_consent_cleared", properties: ["source": "server_inactive"])
            }
            // Always demote account-connected presentation when server consent is inactive,
            // including stale `.connected` without a durable marker (TF167 UI defect).
            if boundUserId == userId {
                demoteConnectedWithoutDurableConsent(for: userId)
            }
        }
    }

    /// Demote stale `.connected` / sync terminal states when durable account consent is missing.
    /// Preserves OS authorization as `.systemAuthorized`. Does not revoke system HK permission.
    @discardableResult
    func demoteConnectedWithoutDurableConsent(for userId: String) -> WearableConnectionState {
        guard !userId.isEmpty else { return connectionState }
        guard boundUserId.isEmpty || boundUserId == userId else { return connectionState }
        guard !hasDurableConsent(for: userId) else { return connectionState }
        switch connectionState {
        case .connected, .dataUnavailable, .syncFailed, .partial:
            connectionState = hasSystemAuthorization(for: userId) ? .systemAuthorized : .notConnected
        default:
            break
        }
        return connectionState
    }

    /// Logout / account switch: cancel work and clear presentation; keep HK system permission.
    func clearAccountSession() {
        cancelPendingSync()
        boundUserId = ""
        connectionState = .notConnected
        lastSyncError = nil
        lastAuthorizationError = nil
        lastSyncAt = nil
        latestSnapshots = []
        latestSleep = nil
    }

    private func markSystemAuthorized(for userId: String) {
        guard !userId.isEmpty else { return }
        defaults.set(true, forKey: authorizationCompletedKey(for: userId))
        boundUserId = userId
        connectionState = .systemAuthorized
    }

    private func markConsentPersisted(for userId: String) {
        guard !userId.isEmpty else { return }
        defaults.set(true, forKey: consentPersistedKey(for: userId))
        defaults.set(true, forKey: authorizationCompletedKey(for: userId))
        boundUserId = userId
        connectionState = .connected
    }

    private func clearConsentPersisted(for userId: String) {
        guard !userId.isEmpty else { return }
        defaults.set(false, forKey: consentPersistedKey(for: userId))
    }

    /// Production uses `.standard`. Unit tests may inject an ephemeral suite so
    /// coordinator races do not share mutable presentation state with the host
    /// app's `HealthKitService.shared` (logout always clears shared).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.array(forKey: tiersKey) as? [Int], !saved.isEmpty {
            enabledTiers = Set(saved)
        }
    }

    // MARK: - Type catalogs

    private func quantityIdentifiers(for tier: HealthConsentTier) -> [HKQuantityTypeIdentifier] {
        switch tier {
        case .activitySleep:
            return [
                .stepCount,
                .distanceWalkingRunning,
                .activeEnergyBurned,
                .basalEnergyBurned,
                .appleExerciseTime,
                .appleStandTime,
                .flightsClimbed,
            ]
        case .heartRecovery:
            return [
                .heartRate,
                .restingHeartRate,
                .walkingHeartRateAverage,
                .heartRateVariabilitySDNN,
                .vo2Max,
                .walkingSpeed,
                .walkingStepLength,
                .walkingAsymmetryPercentage,
                .walkingDoubleSupportPercentage,
            ]
        case .respiratoryTemperature:
            return [
                .respiratoryRate,
                .oxygenSaturation,
                .bodyTemperature,
                .appleSleepingWristTemperature,
            ]
        case .extendedOptIn:
            return [
                .bodyMass,
                .height,
                .bodyFatPercentage,
            ]
        }
    }

    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    private var workoutType: HKSampleType {
        HKObjectType.workoutType()
    }

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    private func readTypes(for tiers: Set<Int>) -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        for raw in tiers {
            guard let tier = HealthConsentTier(rawValue: raw) else { continue }
            for identifier in quantityIdentifiers(for: tier) {
                if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                    types.insert(type)
                }
            }
            if tier == .activitySleep {
                if let sleep = sleepType { types.insert(sleep) }
                types.insert(workoutType)
            }
            if tier == .heartRecovery, let mindful = mindfulType {
                types.insert(mindful)
            }
        }
        return types
    }

    private var activeReadTypes: Set<HKObjectType> {
        readTypes(for: enabledTiers)
    }

    func reportConnectionState(_ state: WearableConnectionState) {
        connectionState = state
    }

    func reportAuthorizationIssue(_ messageKey: String) {
        lastAuthorizationError = messageKey
    }

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func diagnostics() -> HealthKitDiagnostics {
        HealthKitDiagnostics(
            healthDataAvailable: isHealthDataAvailable(),
            shareUsageDescriptionPresent: Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil,
            updateUsageDescriptionPresent: Bundle.main.object(forInfoDictionaryKey: "NSHealthUpdateUsageDescription") != nil,
            readTypeCount: activeReadTypes.count,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        )
    }

    func configurationIssueMessage() -> String? {
        let info = diagnostics()
        guard info.healthDataAvailable else { return "wearable.health.error.unavailable_device" }
        guard info.readTypeCount > 0 else { return "wearable.health.error.no_types" }
        guard info.shareUsageDescriptionPresent else { return "wearable.health.error.missing_plist" }
        guard info.updateUsageDescriptionPresent else { return "wearable.health.error.missing_plist" }
        return nil
    }

    func setEnabledTiers(_ tiers: Set<Int>) {
        enabledTiers = tiers.isEmpty ? [1] : tiers
        defaults.set(Array(enabledTiers).sorted(), forKey: tiersKey)
    }

    func refreshAuthorizationState() -> WearableConnectionState {
        guard isHealthDataAvailable() else {
            connectionState = .unavailable
            return .unavailable
        }
        // Preserve in-progress revoke UI; local consent is already cleared.
        switch connectionState {
        case .revoking, .remoteRevokePending, .revokeFailed, .consentSaving, .consentFailed:
            return connectionState
        default:
            break
        }
        let userId = boundUserId
        if !userId.isEmpty, hasDurableConsent(for: userId) {
            if connectionState != .permissionDenied && connectionState != .unavailable {
                connectionState = .connected
            }
            return connectionState == .permissionDenied || connectionState == .unavailable
                ? connectionState
                : .connected
        }
        // No durable consent: never keep/promote `.connected` (OS auth ≠ account sync).
        if !userId.isEmpty {
            _ = demoteConnectedWithoutDurableConsent(for: userId)
            if hasSystemAuthorization(for: userId) {
                connectionState = .systemAuthorized
                return .systemAuthorized
            }
        }
        if connectionState == .permissionRequested || connectionState == .permissionDenied {
            return connectionState
        }
        if connectionState == .systemAuthorized {
            return .systemAuthorized
        }
        connectionState = .notConnected
        return .notConnected
    }

    func requestAuthorization(tiers: Set<Int>? = nil, userId: String = "") async -> Bool {
        if let authorizationInFlight {
            return await authorizationInFlight.value
        }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            return await self.performAuthorizationRequest(tiers: tiers, userId: userId)
        }
        authorizationInFlight = task
        let result = await task.value
        if authorizationInFlight == task {
            authorizationInFlight = nil
        }
        return result
    }

    private func performAuthorizationRequest(tiers: Set<Int>?, userId: String) async -> Bool {
        lastAuthorizationError = nil
        if let tiers {
            setEnabledTiers(tiers)
        }
        if let issueKey = configurationIssueMessage() {
            lastAuthorizationError = issueKey
            connectionState = .unavailable
            ProductAnalytics.track("health_connect_failed", properties: ["error_code": "config"])
            return false
        }
        connectionState = .permissionRequested
        ProductAnalytics.track("health_authorization_started")
        let types = activeReadTypes
        let outcome = await HealthKitTimeoutRace.raceCallback(
            timeoutNanoseconds: authorizationTimeoutNanoseconds,
            sleeper: timeoutSleeper
        ) { (finish: @escaping @Sendable (NSError?) -> Void) in
            self.store.requestAuthorization(toShare: [], read: types) { _, error in
                finish(error as NSError?)
            }
        }
        switch outcome {
        case .timedOut:
            lastAuthorizationError = "wearable.health.error.generic|timeout"
            connectionState = .syncFailed
            ProductAnalytics.track("health_connect_timeout", properties: ["stage": "authorization"])
            return false
        case let .value(requestError):
            if let requestError {
                lastAuthorizationError = Self.userFacingAuthorizationError(requestError)
                connectionState = .permissionDenied
                ProductAnalytics.track("health_connect_failed", properties: ["error_code": "authorization"])
                return false
            }
            // System sheet completed — durable HiAir consent is a separate step.
            if !userId.isEmpty {
                markSystemAuthorized(for: userId)
            } else {
                connectionState = .systemAuthorized
            }
            ProductAnalytics.track("health_authorization_completed", properties: ["success": "true"])
            return true
        }
    }

    static func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url, options: [:]) { success in
                guard !success, let settings = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settings)
            }
            return
        }
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private static func userFacingAuthorizationError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "com.apple.healthkit", nsError.code == 4 {
            return "wearable.health.error.missing_entitlement"
        }
        if nsError.domain == "com.apple.healthkit", nsError.code == 6 {
            // Protected data / device locked
            return "wearable.health.error.locked"
        }
        let message = nsError.localizedDescription.lowercased()
        if message.contains("usage description") || message.contains("info.plist") {
            return "wearable.health.error.missing_plist"
        }
        if message.contains("entitlement") {
            return "wearable.health.error.missing_entitlement"
        }
        if message.contains("authorization") && message.contains("denied") {
            return "wearable.health.error.denied"
        }
        return "wearable.health.error.generic|\(nsError.localizedDescription)"
    }

    // MARK: - Reads

    func collectTodaySnapshots() async -> ([HealthMetricSnapshot], HealthSleepSnapshot?) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = Date()
        let store = self.store
        let tiers = enabledTiers
        let collected = await HealthKitQueryEngine.collectToday(
            store: store,
            tiers: tiers,
            start: start,
            end: end,
            calendar: calendar
        )
        latestSnapshots = collected.0
        latestSleep = collected.1
        return collected
    }

    // MARK: - Sync

    func saveConsent(userId: String, accessToken: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "com.hiair.healthkit", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "missing_user",
            ])
        }
        let expectedUserId = userId
        if boundUserId.isEmpty || boundUserId == expectedUserId {
            connectionState = .consentSaving
        }
        let tiers = enabledTiers
        do {
            _ = try await apiClient.saveWearableConsent(
                userId: expectedUserId,
                accessToken: accessToken,
                payload: WearableConsentPayload(
                    platform: "ios",
                    source: "apple_health",
                    stepsEnabled: tiers.contains(1),
                    heartRateEnabled: tiers.contains(2),
                    restingHeartRateEnabled: tiers.contains(2),
                    hrvEnabled: tiers.contains(2),
                    sleepEnabled: tiers.contains(1),
                    activityEnabled: tiers.contains(1),
                    sleepStagesEnabled: tiers.contains(1),
                    respiratoryEnabled: tiers.contains(3),
                    temperatureEnabled: tiers.contains(3),
                    workoutsEnabled: tiers.contains(1),
                    fitnessEnabled: tiers.contains(2),
                    bodyMetricsEnabled: tiers.contains(4),
                    sensitiveMetricsEnabled: false,
                    consentVersion: consentVersion
                )
            )
            // Persist durable consent for the account that succeeded on the server.
            // Never steal live bind/connectionState if the session already switched away.
            if boundUserId.isEmpty || boundUserId == expectedUserId {
                markConsentPersisted(for: expectedUserId)
            } else {
                defaults.set(true, forKey: consentPersistedKey(for: expectedUserId))
                defaults.set(true, forKey: authorizationCompletedKey(for: expectedUserId))
                ProductAnalytics.track(
                    "health_consent_persisted_stale_bind",
                    properties: ["reason": "account_switched_after_save"]
                )
            }
        } catch {
            if boundUserId.isEmpty || boundUserId == expectedUserId {
                connectionState = .consentFailed
                clearConsentPersisted(for: expectedUserId)
            }
            throw error
        }
    }

    func cancelPendingSync() {
        syncGeneration &+= 1
        syncInFlight?.cancel()
        syncInFlight = nil
    }

    /// Clear `syncInFlight` only when this generation is still current.
    /// Synchronous on MainActor — never schedules a nested unstructured Task
    /// that could race a replacement sync and wipe the newer handle.
    private func finishSyncInFlight(generation: UInt64) {
        guard syncGeneration == generation else { return }
        syncInFlight = nil
    }

    /// Shared upload/sync gate: cancel + generation + account + durable consent.
    func ensureSyncStillAuthorized(
        userId: String,
        generation: UInt64,
        stage: String
    ) -> Bool {
        guard !Task.isCancelled else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "cancelled", "stage": stage])
            return false
        }
        guard generation == syncGeneration else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "stale_generation", "stage": stage])
            return false
        }
        guard !userId.isEmpty, boundUserId.isEmpty || boundUserId == userId else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "account_mismatch", "stage": stage])
            return false
        }
        guard hasDurableConsent(for: userId) else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "consent_missing", "stage": stage])
            return false
        }
        switch connectionState {
        case .revoking, .remoteRevokePending, .revokeFailed, .notConnected, .consentFailed,
             .permissionDenied, .unavailable, .permissionRequested, .systemAuthorized, .consentSaving:
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "state_blocks_sync", "stage": stage])
            return false
        case .connected, .dataUnavailable, .syncFailed, .partial:
            return true
        }
    }

    /// Canonical public entry — all Views must use this (not ad-hoc sync Tasks).
    /// Spawns a single MainActor coordinator Task; cancel/replace is generation-gated.
    /// Duplicate starts for the same in-flight user are joined so dashboard reloads
    /// cannot restart a 20+ query HealthKit collect.
    func startBackgroundHealthSync(
        userId: String,
        accessToken: String,
        profileId: String?,
        forceRestart: Bool = false
    ) {
        guard let generation = beginHealthSyncGeneration(userId: userId, forceRestart: forceRestart) else { return }
        let expectedUserId = userId
        let token = accessToken
        let profile = profileId
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.finishSyncInFlight(generation: generation) }
            await self.runHealthSyncPipeline(
                userId: expectedUserId,
                accessToken: token,
                profileId: profile,
                generation: generation
            )
        }
        syncInFlight = task
    }

    /// Deterministic, awaitable sync for unit tests.
    /// Runs the same MainActor coordinator Task as production so
    /// `cancelPendingSync` / replace set `Task.isCancelled` on the pipeline.
    /// Scheduled via a detached hop so the XCTest caller task cannot
    /// pre-cancel the coordinator through structured-concurrency inheritance.
    func runHealthSyncForTests(userId: String, accessToken: String, profileId: String?) async {
        guard let generation = beginHealthSyncGeneration(userId: userId, forceRestart: true) else { return }
        let token = accessToken
        let profile = profileId
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task.detached { @MainActor [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                let task = Task { @MainActor [weak self] in
                    defer { continuation.resume() }
                    guard let self else { return }
                    defer { self.finishSyncInFlight(generation: generation) }
                    await self.runHealthSyncPipeline(
                        userId: userId,
                        accessToken: token,
                        profileId: profile,
                        generation: generation
                    )
                }
                self.syncInFlight = task
            }
        }
    }

    private func beginHealthSyncGeneration(userId: String, forceRestart: Bool) -> UInt64? {
        guard hasDurableConsent(for: userId) else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "consent_missing", "stage": "start"])
            return nil
        }
        switch connectionState {
        case .revoking, .remoteRevokePending, .revokeFailed:
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "state_blocks_sync", "stage": "start"])
            return nil
        default:
            break
        }
        if !forceRestart, let existing = syncInFlight, !existing.isCancelled {
            return nil
        }
        // Single-flight: cancel prior task and drop the handle immediately so a
        // cancelled/completed stale Task cannot look "in flight" before the
        // replacement is assigned.
        syncInFlight?.cancel()
        syncInFlight = nil
        syncGeneration &+= 1
        return syncGeneration
    }

    private func runHealthSyncPipeline(
        userId: String,
        accessToken: String,
        profileId: String?,
        generation: UInt64
    ) async {
        guard ensureSyncStillAuthorized(
            userId: userId,
            generation: generation,
            stage: "coordinator_start"
        ) else { return }
        await performHealthSync(
            userId: userId,
            accessToken: accessToken,
            profileId: profileId,
            generation: generation
        )
        guard ensureSyncStillAuthorized(
            userId: userId,
            generation: generation,
            stage: "before_hourly"
        ) else { return }
        await syncWearableHourlySummary(
            userId: userId,
            accessToken: accessToken,
            generation: generation
        )
    }

    /// Legacy name — always routes through the cancellable coordinator.
    func syncWearableDailySummary(userId: String, accessToken: String) async {
        startBackgroundHealthSync(userId: userId, accessToken: accessToken, profileId: nil)
    }

    private func performHealthSync(
        userId: String,
        accessToken: String,
        profileId: String?,
        generation: UInt64
    ) async {
        guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: "before_collect") else {
            return
        }
        ProductAnalytics.track("health_sync_started")
        do {
            let snapshots: [HealthMetricSnapshot]
            let sleep: HealthSleepSnapshot?
            if let testCollectHandler {
                (snapshots, sleep) = await testCollectHandler()
            } else {
                let collectOutcome = await HealthKitTimeoutRace.raceAsync(
                    timeoutNanoseconds: healthCollectTimeoutNanoseconds,
                    sleeper: self.timeoutSleeper
                ) {
                    await self.collectTodaySnapshots()
                }
                guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: "after_collect") else {
                    return
                }
                guard case let .value((collectedSnapshots, collectedSleep)) = collectOutcome else {
                    if generation == syncGeneration {
                        connectionState = .syncFailed
                        lastSyncError = "wearable.health.error.generic|timeout"
                    }
                    ProductAnalytics.track("health_connect_timeout", properties: ["stage": "collect"])
                    return
                }
                snapshots = collectedSnapshots
                sleep = collectedSleep
            }
            guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: "before_payload") else {
                return
            }
            latestSnapshots = snapshots
            latestSleep = sleep
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: Date())
            let tz = TimeZone.current.identifier
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]

            let metrics = snapshots.map { snap in
                HealthMetricSummaryPayload(
                    metricType: snap.metricType,
                    valueAvg: snap.valueAvg,
                    valueMin: snap.valueMin,
                    valueMax: snap.valueMax,
                    valueLatest: snap.valueLatest,
                    valueTotal: snap.valueTotal,
                    unit: snap.unit,
                    sampleCount: snap.sampleCount,
                    qualityState: snap.qualityState,
                    hrvMethod: snap.hrvMethod,
                    sourceDeviceClass: "iphone_or_watch"
                )
            }
            var sleepPayload: HealthSleepSummaryPayload?
            if let sleep {
                sleepPayload = HealthSleepSummaryPayload(
                    localDate: dateString,
                    totalMinutes: sleep.totalMinutes,
                    inBedMinutes: sleep.inBedMinutes,
                    awakeMinutes: sleep.awakeMinutes,
                    coreLightMinutes: sleep.coreLightMinutes,
                    deepMinutes: sleep.deepMinutes,
                    remMinutes: sleep.remMinutes,
                    sleepStart: sleep.sleepStart.map { iso.string(from: $0) },
                    sleepEnd: sleep.sleepEnd.map { iso.string(from: $0) },
                    qualityState: sleep.qualityState
                )
            }
            let idempotency = "ios-\(dateString)-\(Int(Date().timeIntervalSince1970 / 300))"
            guard await prepareUpload(userId: userId, generation: generation, stage: "health_sync") else {
                return
            }
            if testCollectHandler != nil {
                guard await prepareUpload(userId: userId, generation: generation, stage: "daily_summary") else {
                    return
                }
                guard generation == syncGeneration, boundUserId.isEmpty || boundUserId == userId else { return }
                guard hasDurableConsent(for: userId) else {
                    _ = demoteConnectedWithoutDurableConsent(for: userId)
                    return
                }
                connectionState = metrics.isEmpty && sleepPayload == nil ? .dataUnavailable : .connected
                lastSyncError = nil
                lastSyncAt = Date()
                ProductAnalytics.track(
                    "health_sync_completed",
                    properties: [
                        "success": "true",
                        "empty": (metrics.isEmpty && sleepPayload == nil) ? "true" : "false",
                        "mode": "test",
                    ]
                )
                return
            }
            _ = try await apiClient.syncHealthData(
                userId: userId,
                accessToken: accessToken,
                payload: HealthSyncPayload(
                    profileId: profileId,
                    localDate: dateString,
                    timezone: tz,
                    platform: "ios",
                    source: "apple_health",
                    clientSyncVersion: consentVersion,
                    idempotencyKey: idempotency,
                    metrics: metrics,
                    sleep: sleepPayload,
                    cursorMetadata: ["mode": "foreground_daily"]
                )
            )
            let steps = snapshots.first(where: { $0.metricType == "steps" })?.valueTotal.map { Int($0) }
            let hr = snapshots.first(where: { $0.metricType == "heart_rate" })
            let resting = snapshots.first(where: { $0.metricType == "resting_heart_rate" })?.valueLatest
            guard await prepareUpload(userId: userId, generation: generation, stage: "daily_summary") else {
                return
            }
            _ = try await apiClient.uploadWearableDailySummary(
                userId: userId,
                accessToken: accessToken,
                payload: WearableDailySummaryPayload(
                    date: dateString,
                    stepsTotal: steps,
                    heartRateAvg: hr?.valueAvg,
                    heartRateMin: hr?.valueMin,
                    heartRateMax: hr?.valueMax,
                    restingHeartRateAvg: resting,
                    source: "apple_health"
                )
            )
            guard generation == syncGeneration, boundUserId.isEmpty || boundUserId == userId else { return }
            guard hasDurableConsent(for: userId) else {
                _ = demoteConnectedWithoutDurableConsent(for: userId)
                return
            }
            connectionState = metrics.isEmpty && sleepPayload == nil ? .dataUnavailable : .connected
            lastSyncError = nil
            lastSyncAt = Date()
            ProductAnalytics.track(
                "health_sync_completed",
                properties: [
                    "success": "true",
                    "empty": (metrics.isEmpty && sleepPayload == nil) ? "true" : "false",
                ]
            )
        } catch {
            guard generation == syncGeneration else { return }
            let nsError = error as NSError
            if nsError.domain == "com.apple.healthkit", nsError.code == 6 {
                connectionState = .syncFailed
                lastSyncError = "wearable.health.error.locked"
            } else {
                connectionState = .syncFailed
                lastSyncError = error.localizedDescription
            }
            ProductAnalytics.track("health_connect_failed", properties: ["error_code": "sync"])
        }
    }

    private func prepareUpload(userId: String, generation: UInt64, stage: String) async -> Bool {
        guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: stage) else {
            return false
        }
        testUploadGateReachedCount += 1
        if let testBeforeUploadHook {
            await testBeforeUploadHook()
            guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: "\(stage)_after_hook") else {
                return false
            }
        }
        testUploadAttemptCount += 1
        return true
    }

    func syncWearableHourlySummary(
        userId: String,
        accessToken: String,
        generation: UInt64? = nil
    ) async {
        let generation = generation ?? syncGeneration
        guard ensureSyncStillAuthorized(userId: userId, generation: generation, stage: "hourly_start") else {
            return
        }
        let hourly: [(hourStart: Date, steps: Int, hrAvg: Double?, hrMax: Double?)]
        if testCollectHandler != nil {
            // Deterministic tests skip real hourly HealthKit queries.
            hourly = []
        } else {
            hourly = await fetchHourlyActivitySummary()
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        for entry in hourly where entry.steps > 0 || entry.hrAvg != nil {
            guard await prepareUpload(userId: userId, generation: generation, stage: "hourly_batch") else {
                return
            }
            _ = try? await apiClient.uploadWearableHourlySummary(
                userId: userId,
                accessToken: accessToken,
                payload: WearableHourlySummaryPayload(
                    hourStart: iso.string(from: entry.hourStart),
                    stepsTotal: entry.steps,
                    heartRateAvg: entry.hrAvg,
                    heartRateMax: entry.hrMax,
                    source: "apple_health"
                )
            )
        }
    }

    /// Immediately blocks sync and clears local durable consent (before any network await).
    private func revokeLocalConsentImmediately(userId: String, presenting state: WearableConnectionState) {
        cancelPendingSync()
        clearConsentPersisted(for: userId)
        defaults.set(false, forKey: authorizationCompletedKey(for: userId))
        if boundUserId == userId || boundUserId.isEmpty {
            connectionState = state
            latestSnapshots = []
            latestSleep = nil
            lastSyncAt = nil
            lastSyncError = nil
        }
    }

    func revokeConsent(userId: String, accessToken: String) async {
        revokeLocalConsentImmediately(userId: userId, presenting: .revoking)
        do {
            if let testRemoteRevokeHandler {
                try await testRemoteRevokeHandler()
            } else {
                _ = try await apiClient.revokeWearableConsent(userId: userId, accessToken: accessToken)
            }
            guard boundUserId.isEmpty || boundUserId == userId else { return }
            connectionState = .notConnected
        } catch {
            guard boundUserId.isEmpty || boundUserId == userId else { return }
            connectionState = .remoteRevokePending
            lastSyncError = error.localizedDescription
            ProductAnalytics.track("health_revoke_remote_failed", properties: ["error_code": "remote"])
        }
    }

    func deleteHealthData(userId: String, accessToken: String) async {
        revokeLocalConsentImmediately(userId: userId, presenting: .revoking)
        let prefix = anchorKeyPrefix
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        do {
            if let testRemoteDeleteHandler {
                try await testRemoteDeleteHandler()
            } else {
                _ = try await apiClient.deleteHealthData(userId: userId, accessToken: accessToken)
                _ = try await apiClient.deleteWearableData(userId: userId, accessToken: accessToken)
            }
            guard boundUserId.isEmpty || boundUserId == userId else { return }
            connectionState = .notConnected
        } catch {
            guard boundUserId.isEmpty || boundUserId == userId else { return }
            connectionState = .revokeFailed
            lastSyncError = error.localizedDescription
            ProductAnalytics.track("health_delete_remote_failed", properties: ["error_code": "remote"])
        }
    }

    func resetTestHooks() {
        testCollectHandler = nil
        testBeforeUploadHook = nil
        testRemoteRevokeHandler = nil
        testRemoteDeleteHandler = nil
        testUploadGateReachedCount = 0
        testUploadAttemptCount = 0
        authorizationTimeoutNanoseconds = 60_000_000_000
        healthCollectTimeoutNanoseconds = 45_000_000_000
        timeoutSleeper = SystemNanosleeper()
    }

    /// Test-only: write durable consent markers into this instance's defaults suite.
    func seedDurableConsentMarkersForTests(
        userId: String,
        authorized: Bool = true,
        consented: Bool = true
    ) {
        defaults.set(authorized, forKey: authorizationCompletedKey(for: userId))
        defaults.set(consented, forKey: consentPersistedKey(for: userId))
    }

    /// Call from unit-test setUp to keep an instance deterministic and fast.
    /// Does not alter production logout/cleanup semantics on `shared`.
    func prepareForUnitTests() {
        cancelPendingSync()
        clearAccountSession()
        resetTestHooks()
        authorizationTimeoutNanoseconds = 1_000_000
        healthCollectTimeoutNanoseconds = 1_000_000
        timeoutSleeper = ImmediateNanosleeper()
    }

    // MARK: - Legacy helpers kept for dashboard

    func fetchTodaySteps() async -> Int? {
        let snaps = await collectTodaySnapshots().0
        return snaps.first(where: { $0.metricType == "steps" })?.valueTotal.map { Int($0) }
    }

    func fetchTodayHeartRateSummary() async -> (avg: Double?, min: Double?, max: Double?) {
        let snaps = await collectTodaySnapshots().0
        guard let hr = snaps.first(where: { $0.metricType == "heart_rate" }) else { return (nil, nil, nil) }
        return (hr.valueAvg, hr.valueMin, hr.valueMax)
    }

    func fetchRestingHeartRate() async -> Double? {
        let snaps = await collectTodaySnapshots().0
        return snaps.first(where: { $0.metricType == "resting_heart_rate" })?.valueLatest
    }

    func fetchHourlyActivitySummary() async -> [(hourStart: Date, steps: Int, hrAvg: Double?, hrMax: Double?)] {
        let store = self.store
        return await HealthKitQueryEngine.hourlyActivity(store: store)
    }
}
