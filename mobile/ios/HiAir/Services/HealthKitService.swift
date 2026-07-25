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

struct HealthMetricSnapshot: Equatable {
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

struct HealthSleepSnapshot: Equatable {
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
    private let defaults = UserDefaults.standard
    private let tiersKey = "hiair.health.enabledTiers"
    private let anchorKeyPrefix = "hiair.health.anchor."
    private var authorizationInFlight: Task<Bool, Never>?
    private var syncInFlight: Task<Void, Never>?
    private var syncGeneration: UInt64 = 0
    /// Authenticated HiAir user that owns current connection/consent presentation state.
    private(set) var boundUserId: String = ""
    private let healthQueryTimeoutSeconds: TimeInterval = 12
    /// Overridable for unit tests (default 60s).
    var authorizationTimeoutNanoseconds: UInt64 = 60_000_000_000
    /// Overridable for unit tests (default 45s collect).
    var healthCollectTimeoutNanoseconds: UInt64 = 45_000_000_000
    /// Test seam: replace HealthKit collect (deterministic race tests).
    var testCollectHandler: (() async -> ([HealthMetricSnapshot], HealthSleepSnapshot?))?
    /// Test seam: run before each network upload (e.g. slow remote).
    var testBeforeUploadHook: (() async -> Void)?
    /// Test seam: replace remote revoke/delete network calls.
    var testRemoteRevokeHandler: (() async throws -> Void)?
    var testRemoteDeleteHandler: (() async throws -> Void)?
    /// Counts upload attempts that passed the consent/generation gate.
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

    init() {
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
        if !userId.isEmpty, hasSystemAuthorization(for: userId) {
            connectionState = .systemAuthorized
            return .systemAuthorized
        }
        if connectionState == .permissionRequested || connectionState == .permissionDenied {
            return connectionState
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
            timeoutNanoseconds: authorizationTimeoutNanoseconds
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
        var snapshots: [HealthMetricSnapshot] = []
        let tiers = enabledTiers
        let tier1 = tiers.contains(1)
        let tier2 = tiers.contains(2)
        let tier3 = tiers.contains(3)

        if tier1 {
            snapshots.append(contentsOf: await collectCumulative(
                id: .stepCount, metric: "steps", unit: HKUnit.count(), unitName: "count", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .distanceWalkingRunning, metric: "distance_walking_running", unit: HKUnit.meter(), unitName: "m", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .activeEnergyBurned, metric: "active_energy", unit: HKUnit.kilocalorie(), unitName: "kcal", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .basalEnergyBurned, metric: "basal_energy", unit: HKUnit.kilocalorie(), unitName: "kcal", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .appleExerciseTime, metric: "exercise_minutes", unit: HKUnit.minute(), unitName: "min", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .appleStandTime, metric: "stand_minutes", unit: HKUnit.minute(), unitName: "min", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectCumulative(
                id: .flightsClimbed, metric: "flights_climbed", unit: HKUnit.count(), unitName: "count", start: start, end: end
            ))
            snapshots.append(contentsOf: await collectWorkoutAggregates(start: start, end: end))
        }

        if tier2 {
            if let hr = await collectDiscreteStats(
                id: .heartRate,
                metric: "heart_rate",
                unit: HKUnit.count().unitDivided(by: .minute()),
                unitName: "bpm",
                start: start,
                end: end
            ) { snapshots.append(hr) }

            if let resting = await collectLatest(
                id: .restingHeartRate,
                metric: "resting_heart_rate",
                unit: HKUnit.count().unitDivided(by: .minute()),
                unitName: "bpm",
                start: calendar.date(byAdding: .day, value: -1, to: start) ?? start,
                end: end
            ) { snapshots.append(resting) }

            if let walking = await collectLatest(
                id: .walkingHeartRateAverage,
                metric: "walking_heart_rate_avg",
                unit: HKUnit.count().unitDivided(by: .minute()),
                unitName: "bpm",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end
            ) { snapshots.append(walking) }

            if let hrv = await collectDiscreteStats(
                id: .heartRateVariabilitySDNN,
                metric: "hrv_sdnn",
                unit: HKUnit.secondUnit(with: .milli),
                unitName: "ms",
                start: start,
                end: end,
                hrvMethod: "sdnn"
            ) { snapshots.append(hrv) }

            if let vo2 = await collectLatest(
                id: .vo2Max,
                metric: "vo2_max",
                unit: HKUnit(from: "ml/kg*min"),
                unitName: "ml_kg_min",
                start: calendar.date(byAdding: .day, value: -90, to: start) ?? start,
                end: end
            ) { snapshots.append(vo2) }

            if let mindfulness = await collectMindfulnessMinutes(start: start, end: end) {
                snapshots.append(mindfulness)
            }

            if let speed = await collectLatest(
                id: .walkingSpeed,
                metric: "walking_speed",
                unit: HKUnit.meter().unitDivided(by: .second()),
                unitName: "m_s",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end
            ) { snapshots.append(speed) }

            if let stepLength = await collectLatest(
                id: .walkingStepLength,
                metric: "walking_step_length",
                unit: HKUnit.meter(),
                unitName: "m",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end
            ) { snapshots.append(stepLength) }

            if let asymmetry = await collectLatest(
                id: .walkingAsymmetryPercentage,
                metric: "walking_asymmetry",
                unit: HKUnit.percent(),
                unitName: "percent",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end,
                scale: 100
            ) { snapshots.append(asymmetry) }

            if let doubleSupport = await collectLatest(
                id: .walkingDoubleSupportPercentage,
                metric: "walking_double_support",
                unit: HKUnit.percent(),
                unitName: "percent",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end,
                scale: 100
            ) { snapshots.append(doubleSupport) }
        }

        if tier3 {
            if let rr = await collectDiscreteStats(
                id: .respiratoryRate,
                metric: "respiratory_rate",
                unit: HKUnit.count().unitDivided(by: .minute()),
                unitName: "breaths_per_min",
                start: start,
                end: end
            ) { snapshots.append(rr) }

            if let spo2 = await collectDiscreteStats(
                id: .oxygenSaturation,
                metric: "oxygen_saturation",
                unit: HKUnit.percent(),
                unitName: "percent",
                start: start,
                end: end,
                scale: 100
            ) { snapshots.append(spo2) }

            if let bodyTemp = await collectLatest(
                id: .bodyTemperature,
                metric: "body_temperature",
                unit: HKUnit.degreeCelsius(),
                unitName: "celsius",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end
            ) { snapshots.append(bodyTemp) }

            if let wrist = await collectLatest(
                id: .appleSleepingWristTemperature,
                metric: "wrist_temperature",
                unit: HKUnit.degreeCelsius(),
                unitName: "celsius",
                start: calendar.date(byAdding: .day, value: -7, to: start) ?? start,
                end: end
            ) { snapshots.append(wrist) }
        }

        let sleep = tier1 ? await collectSleep(for: start) : nil
        latestSnapshots = snapshots
        latestSleep = sleep
        return (snapshots, sleep)
    }

    // MARK: - Sync

    func saveConsent(userId: String, accessToken: String) async throws {
        guard !userId.isEmpty else {
            throw NSError(domain: "com.hiair.healthkit", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "missing_user",
            ])
        }
        connectionState = .consentSaving
        let tiers = enabledTiers
        do {
            _ = try await apiClient.saveWearableConsent(
                userId: userId,
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
            guard boundUserId.isEmpty || boundUserId == userId else { return }
            markConsentPersisted(for: userId)
        } catch {
            if boundUserId.isEmpty || boundUserId == userId {
                connectionState = .consentFailed
                clearConsentPersisted(for: userId)
            }
            throw error
        }
    }

    func cancelPendingSync() {
        syncGeneration &+= 1
        syncInFlight?.cancel()
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

    /// Canonical public entry — all Views must use this (not unstructured sync Tasks).
    func startBackgroundHealthSync(userId: String, accessToken: String, profileId: String?) {
        guard hasDurableConsent(for: userId) else {
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "consent_missing", "stage": "start"])
            return
        }
        switch connectionState {
        case .revoking, .remoteRevokePending, .revokeFailed:
            ProductAnalytics.track("health_sync_blocked", properties: ["reason": "state_blocks_sync", "stage": "start"])
            return
        default:
            break
        }
        // Single-flight: replace any prior operation with a fresh generation-bound task.
        syncInFlight?.cancel()
        syncGeneration &+= 1
        let generation = syncGeneration
        let expectedUserId = userId
        syncInFlight = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.syncGeneration == generation {
                        self.syncInFlight = nil
                    }
                }
            }
            guard self.ensureSyncStillAuthorized(
                userId: expectedUserId,
                generation: generation,
                stage: "coordinator_start"
            ) else { return }
            await self.performHealthSync(
                userId: expectedUserId,
                accessToken: accessToken,
                profileId: profileId,
                generation: generation
            )
            guard self.ensureSyncStillAuthorized(
                userId: expectedUserId,
                generation: generation,
                stage: "before_hourly"
            ) else { return }
            await self.syncWearableHourlySummary(
                userId: expectedUserId,
                accessToken: accessToken,
                generation: generation
            )
        }
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
                    timeoutNanoseconds: healthCollectTimeoutNanoseconds
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
        testUploadAttemptCount = 0
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
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var results: [(Date, Int, Double?, Double?)] = []
        for offset in 0..<24 {
            guard let hourStart = calendar.date(
                byAdding: .hour,
                value: -offset,
                to: calendar.dateInterval(of: .hour, for: now)?.start ?? now
            ) else { continue }
            guard let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else { continue }
            let predicate = HKQuery.predicateForSamples(withStart: hourStart, end: hourEnd, options: .strictStartDate)
            let steps = await sumQuantity(type: stepType, unit: .count(), predicate: predicate) ?? 0
            var hrAvg: Double?
            var hrMax: Double?
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let hrSamples = await fetchQuantitySamples(type: hrType, predicate: predicate)
                if !hrSamples.isEmpty {
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    let values = hrSamples.map { $0.quantity.doubleValue(for: unit) }
                    hrAvg = values.reduce(0, +) / Double(values.count)
                    hrMax = values.max()
                }
            }
            results.append((hourStart, Int(steps.rounded()), hrAvg, hrMax))
        }
        return results
    }

    // MARK: - Private collectors

    private func collectCumulative(
        id: HKQuantityTypeIdentifier,
        metric: String,
        unit: HKUnit,
        unitName: String,
        start: Date,
        end: Date
    ) async -> [HealthMetricSnapshot] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return [HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "unsupported", hrvMethod: nil
            )]
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let total = await sumQuantity(type: type, unit: unit, predicate: predicate)
        if let total {
            return [HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: total, sampleCount: 1, qualityState: "ok", hrvMethod: nil
            )]
        }
        return [HealthMetricSnapshot(
            metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
            valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
        )]
    }

    private func collectDiscreteStats(
        id: HKQuantityTypeIdentifier,
        metric: String,
        unit: HKUnit,
        unitName: String,
        start: Date,
        end: Date,
        hrvMethod: String? = nil,
        scale: Double = 1
    ) async -> HealthMetricSnapshot? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "unsupported", hrvMethod: hrvMethod
            )
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples = await fetchQuantitySamples(type: type, predicate: predicate)
        guard !samples.isEmpty else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: hrvMethod
            )
        }
        let values = samples.map { $0.quantity.doubleValue(for: unit) * scale }
        return HealthMetricSnapshot(
            metricType: metric,
            unit: unitName,
            valueAvg: values.reduce(0, +) / Double(values.count),
            valueMin: values.min(),
            valueMax: values.max(),
            valueLatest: values.last,
            valueTotal: nil,
            sampleCount: values.count,
            qualityState: "ok",
            hrvMethod: hrvMethod
        )
    }

    private func collectLatest(
        id: HKQuantityTypeIdentifier,
        metric: String,
        unit: HKUnit,
        unitName: String,
        start: Date,
        end: Date,
        scale: Double = 1
    ) async -> HealthMetricSnapshot? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "unsupported", hrvMethod: nil
            )
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples = await fetchQuantitySamples(type: type, predicate: predicate)
        guard let latest = samples.last else {
            return HealthMetricSnapshot(
                metricType: metric, unit: unitName, valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
            )
        }
        let value = latest.quantity.doubleValue(for: unit) * scale
        return HealthMetricSnapshot(
            metricType: metric,
            unit: unitName,
            valueAvg: value,
            valueMin: nil,
            valueMax: nil,
            valueLatest: value,
            valueTotal: nil,
            sampleCount: 1,
            qualityState: "ok",
            hrvMethod: nil
        )
    }

    private func collectMindfulnessMinutes(start: Date, end: Date) async -> HealthMetricSnapshot? {
        guard let mindfulType else {
            return HealthMetricSnapshot(
                metricType: "mindfulness_minutes",
                unit: "min",
                valueAvg: nil,
                valueMin: nil,
                valueMax: nil,
                valueLatest: nil,
                valueTotal: nil,
                sampleCount: 0,
                qualityState: "unsupported",
                hrvMethod: nil
            )
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        guard !samples.isEmpty else {
            return HealthMetricSnapshot(
                metricType: "mindfulness_minutes",
                unit: "min",
                valueAvg: nil,
                valueMin: nil,
                valueMax: nil,
                valueLatest: nil,
                valueTotal: nil,
                sampleCount: 0,
                qualityState: "no_records",
                hrvMethod: nil
            )
        }
        let totalMinutes = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
        return HealthMetricSnapshot(
            metricType: "mindfulness_minutes",
            unit: "min",
            valueAvg: nil,
            valueMin: nil,
            valueMax: nil,
            valueLatest: nil,
            valueTotal: totalMinutes,
            sampleCount: samples.count,
            qualityState: "ok",
            hrvMethod: nil
        )
    }

    private func collectWorkoutAggregates(start: Date, end: Date) async -> [HealthMetricSnapshot] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        if workouts.isEmpty {
            return [
                HealthMetricSnapshot(
                    metricType: "workout_count", unit: "count", valueAvg: nil, valueMin: nil, valueMax: nil,
                    valueLatest: nil, valueTotal: nil, sampleCount: 0, qualityState: "no_records", hrvMethod: nil
                ),
            ]
        }
        let totalMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
        return [
            HealthMetricSnapshot(
                metricType: "workout_count", unit: "count", valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: Double(workouts.count), sampleCount: workouts.count,
                qualityState: "ok", hrvMethod: nil
            ),
            HealthMetricSnapshot(
                metricType: "workout_duration", unit: "min", valueAvg: nil, valueMin: nil, valueMax: nil,
                valueLatest: nil, valueTotal: totalMinutes, sampleCount: workouts.count,
                qualityState: "ok", hrvMethod: nil
            ),
        ]
    }

    private func collectSleep(for dayStart: Date) async -> HealthSleepSnapshot? {
        guard let sleepType else {
            return HealthSleepSnapshot(
                totalMinutes: nil, inBedMinutes: nil, awakeMinutes: nil, coreLightMinutes: nil,
                deepMinutes: nil, remMinutes: nil, sleepStart: nil, sleepEnd: nil, qualityState: "unsupported"
            )
        }
        // Sleep night typically ends on this morning: look back 24h from noon.
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .hour, value: -36, to: dayStart) ?? dayStart
        let windowEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        guard !samples.isEmpty else {
            return HealthSleepSnapshot(
                totalMinutes: nil, inBedMinutes: nil, awakeMinutes: nil, coreLightMinutes: nil,
                deepMinutes: nil, remMinutes: nil, sleepStart: nil, sleepEnd: nil, qualityState: "no_records"
            )
        }

        var awake = 0.0
        var coreLight = 0.0
        var deep = 0.0
        var rem = 0.0
        var inBed = 0.0
        var asleepStart: Date?
        var asleepEnd: Date?

        for sample in samples {
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            switch value {
            case .awake:
                awake += minutes
            case .asleepCore, .asleepUnspecified:
                coreLight += minutes
                asleepStart = asleepStart.map { min($0, sample.startDate) } ?? sample.startDate
                asleepEnd = asleepEnd.map { max($0, sample.endDate) } ?? sample.endDate
            case .asleepDeep:
                deep += minutes
                asleepStart = asleepStart.map { min($0, sample.startDate) } ?? sample.startDate
                asleepEnd = asleepEnd.map { max($0, sample.endDate) } ?? sample.endDate
            case .asleepREM:
                rem += minutes
                asleepStart = asleepStart.map { min($0, sample.startDate) } ?? sample.startDate
                asleepEnd = asleepEnd.map { max($0, sample.endDate) } ?? sample.endDate
            case .inBed:
                inBed += minutes
            default:
                // Includes awakeInBed / future cases without failing compilation on older SDKs.
                if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                    awake += minutes
                }
            }
        }
        let total = coreLight + deep + rem
        let hasStages = deep > 0 || rem > 0 || coreLight > 0
        let quality = hasStages ? (deep > 0 || rem > 0 ? "ok" : "partial") : (total > 0 ? "partial" : "no_records")
        return HealthSleepSnapshot(
            totalMinutes: total > 0 ? Int(total.rounded()) : nil,
            inBedMinutes: inBed > 0 ? Int(inBed.rounded()) : nil,
            awakeMinutes: awake > 0 ? Int(awake.rounded()) : nil,
            coreLightMinutes: coreLight > 0 ? Int(coreLight.rounded()) : nil,
            deepMinutes: deep > 0 ? Int(deep.rounded()) : nil,
            remMinutes: rem > 0 ? Int(rem.rounded()) : nil,
            sleepStart: asleepStart,
            sleepEnd: asleepEnd,
            qualityState: quality
        )
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    let ns = error as NSError
                    if ns.domain == "com.apple.healthkit", ns.code == 6 {
                        continuation.resume(returning: nil)
                        return
                    }
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchQuantitySamples(type: HKQuantityType, predicate: NSPredicate) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }
}
