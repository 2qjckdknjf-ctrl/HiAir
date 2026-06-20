import Foundation
import HealthKit

struct HealthSnapshot {
    let available: Bool
    let steps: Int?
    let restingHeartRate: Int?
    let sleepHours: Double?
    let sleepQuality: Int?
    let statusMessage: String
}

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func readOptionalSnapshot(language: String, optedIn: Bool) async -> HealthSnapshot {
        guard optedIn else {
            return HealthSnapshot(
                available: false,
                statusMessage: HiAirL10n.t("health.skipped", lang: language)
            )
        }
        guard isAvailable else {
            return HealthSnapshot(
                available: false,
                statusMessage: HiAirL10n.t("health.not_available", lang: language)
            )
        }
        return HealthSnapshot(
            available: false,
                statusMessage: HiAirL10n.t("health.foundation_only", lang: language)
        )
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }
}
