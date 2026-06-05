import Foundation
import HealthKit
import UIKit

enum WearableConnectionState: String, Equatable {
    case notConnected
    case permissionRequested
    case connected
    case permissionDenied
    case dataUnavailable
    case syncFailed
    case unavailable
}

struct HealthKitDiagnostics: Equatable {
    let healthDataAvailable: Bool
    let shareUsageDescriptionPresent: Bool
    let updateUsageDescriptionPresent: Bool
    let readTypeCount: Int
    let buildNumber: String
}

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published private(set) var connectionState: WearableConnectionState = .notConnected
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastAuthorizationError: String?

    private let store = HKHealthStore()
    private let apiClient = APIClient.live()
    private let consentVersion = "wearables-v1"

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(hr)
        }
        if let resting = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(resting)
        }
        return types
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
            readTypeCount: readTypes.count,
            buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        )
    }

    func configurationIssueMessage() -> String? {
        let info = diagnostics()
        guard info.healthDataAvailable else {
            return "wearable.health.error.unavailable_device"
        }
        guard info.readTypeCount > 0 else {
            return "wearable.health.error.no_types"
        }
        guard info.shareUsageDescriptionPresent else {
            return "wearable.health.error.missing_plist"
        }
        guard info.updateUsageDescriptionPresent else {
            return "wearable.health.error.missing_plist"
        }
        return nil
    }

    func refreshAuthorizationState() -> WearableConnectionState {
        guard isHealthDataAvailable() else {
            connectionState = .unavailable
            return .unavailable
        }
        if hasAnyReadAuthorization() {
            connectionState = .connected
            return .connected
        }
        if allReadTypesExplicitlyDenied() {
            connectionState = .permissionDenied
            return .permissionDenied
        }
        connectionState = .notConnected
        return .notConnected
    }

    func requestAuthorization() async -> Bool {
        lastAuthorizationError = nil

        if let issueKey = configurationIssueMessage() {
            lastAuthorizationError = issueKey
            connectionState = .unavailable
            return false
        }

        connectionState = .permissionRequested

        let requestError = await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { _, error in
                continuation.resume(returning: error)
            }
        }

        if let requestError {
            lastAuthorizationError = Self.userFacingAuthorizationError(requestError)
            connectionState = .permissionDenied
            return false
        }

        // Read permission is intentionally opaque; completing requestAuthorization registers
        // the app in Health → Privacy → Apps even when read grant status stays unknown.
        connectionState = .connected
        return true
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

    private func hasAnyReadAuthorization() -> Bool {
        readTypes.contains { store.authorizationStatus(for: $0) == .sharingAuthorized }
    }

    private func allReadTypesExplicitlyDenied() -> Bool {
        !readTypes.isEmpty && readTypes.allSatisfy { store.authorizationStatus(for: $0) == .sharingDenied }
    }

    func fetchTodaySteps() async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await sumQuantity(type: type, unit: .count(), predicate: predicate)
    }

    func fetchTodayHeartRateSummary() async -> (avg: Double?, min: Double?, max: Double?) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return (nil, nil, nil)
        }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let samples = await fetchQuantitySamples(type: type, predicate: predicate)
        guard !samples.isEmpty else { return (nil, nil, nil) }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        return (values.reduce(0, +) / Double(values.count), values.min(), values.max())
    }

    func fetchRestingHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let samples = await fetchQuantitySamples(type: type, predicate: predicate)
        guard let latest = samples.last else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        return latest.quantity.doubleValue(for: unit)
    }

    func fetchHourlyActivitySummary() async -> [(hourStart: Date, steps: Int, hrAvg: Double?, hrMax: Double?)] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let now = Date()
        var results: [(Date, Int, Double?, Double?)] = []
        for offset in 0..<24 {
            guard let hourStart = calendar.date(byAdding: .hour, value: -offset, to: calendar.dateInterval(of: .hour, for: now)?.start ?? now) else {
                continue
            }
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
            results.append((hourStart, steps, hrAvg, hrMax))
        }
        return results
    }

    func saveConsent(userId: String, accessToken: String) async throws {
        _ = try await apiClient.saveWearableConsent(
            userId: userId,
            accessToken: accessToken,
            payload: WearableConsentPayload(
                platform: "ios",
                source: "apple_health",
                stepsEnabled: true,
                heartRateEnabled: true,
                restingHeartRateEnabled: true,
                hrvEnabled: false,
                sleepEnabled: false,
                consentVersion: consentVersion
            )
        )
    }

    func syncWearableDailySummary(userId: String, accessToken: String) async {
        do {
            let steps = await fetchTodaySteps()
            let hr = await fetchTodayHeartRateSummary()
            let resting = await fetchRestingHeartRate()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let dateString = formatter.string(from: Date())
            _ = try await apiClient.uploadWearableDailySummary(
                userId: userId,
                accessToken: accessToken,
                payload: WearableDailySummaryPayload(
                    date: dateString,
                    stepsTotal: steps,
                    heartRateAvg: hr.avg,
                    heartRateMin: hr.min,
                    heartRateMax: hr.max,
                    restingHeartRateAvg: resting,
                    source: "apple_health"
                )
            )
            connectionState = .connected
            lastSyncError = nil
        } catch {
            connectionState = .syncFailed
            lastSyncError = error.localizedDescription
        }
    }

    func syncWearableHourlySummary(userId: String, accessToken: String) async {
        let hourly = await fetchHourlyActivitySummary()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        for entry in hourly where entry.steps > 0 || entry.hrAvg != nil {
            do {
                _ = try await apiClient.uploadWearableHourlySummary(
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
            } catch {
                lastSyncError = error.localizedDescription
            }
        }
    }

    func revokeConsent(userId: String, accessToken: String) async {
        _ = try? await apiClient.revokeWearableConsent(userId: userId, accessToken: accessToken)
        connectionState = .notConnected
    }

    func deleteHealthData(userId: String, accessToken: String) async {
        _ = try? await apiClient.deleteWearableData(userId: userId, accessToken: accessToken)
        connectionState = .notConnected
    }

    private func sumQuantity(type: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Int? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value.map { Int($0) })
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
