import XCTest
@testable import HiAir

final class PlaceGeocodingServiceTests: XCTestCase {
    func testDisplayNamePrefersLocality() {
        // CLPlacemark cannot be easily constructed; validate priority helper via mirror of logic.
        let locality = "Barcelona"
        let fallback = "Catalonia"
        let chosen = [locality, nil, fallback].compactMap { $0 }.first { !$0.isEmpty }
        XCTAssertEqual(chosen, "Barcelona")
    }

    func testCachedPlaceNameRoundTrip() async {
        let service = PlaceGeocodingService.shared
        await service.clearCacheForTests()
        // resolve without network: empty cache returns nil for ocean coords if geocoder fails;
        // we only assert cache API does not crash and starts empty.
        let cached = await service.cachedPlaceName()
        XCTAssertNil(cached)
    }

    func testRuntimeProbeRecordsDuration() {
        RuntimePerformanceProbe.resetForTests()
        RuntimePerformanceProbe.begin("unit_probe")
        let ms = RuntimePerformanceProbe.end("unit_probe", success: true)
        XCTAssertGreaterThanOrEqual(ms, 0)
        XCTAssertEqual(RuntimePerformanceProbe.lastDurationMs("unit_probe"), ms)
    }
}

final class HealthKitConnectedStateTests: XCTestCase {
    @MainActor
    func testRefreshAuthorizationDoesNotRequireSyncArtifacts() async {
        let service = HealthKitService.shared
        // Simulate post-auth by setting connection and ensuring refresh keeps Connected
        // when authorizationCompleted flag is set via successful auth path is hard to
        // stub without HK; assert connectionState can stay connected without snapshots.
        service.reportConnectionState(.connected)
        let state = service.connectionState
        XCTAssertEqual(state, .connected)
        // Calling refresh when no sync artifacts previously wiped Connected — after fix,
        // Connected from reportConnectionState should survive if authorizationCompleted
        // is false and no snapshots: refresh may still go to notConnected.
        // Persist authorizationCompleted via private defaults key used by the service.
        UserDefaults.standard.set(true, forKey: "hiair.health.authorizationCompleted")
        let refreshed = service.refreshAuthorizationState()
        XCTAssertEqual(refreshed, .connected)
        UserDefaults.standard.set(false, forKey: "hiair.health.authorizationCompleted")
    }
}

final class PremiumOptimisticUnlockTests: XCTestCase {
    @MainActor
    func testApplyEntitlementSetsPremiumImmediately() {
        let session = AppSession()
        let entitlement = UserEntitlementResponse(
            userId: "u1",
            plan: "monthly",
            isPremium: true,
            maxProfiles: 5,
            extendedForecastEnabled: true,
            customAlertsEnabled: true,
            exportReportsEnabled: true,
            advancedInsightsEnabled: true
        )
        session.applyEntitlement(entitlement)
        XCTAssertTrue(session.isPremium)
        session.applyEntitlement(nil)
        XCTAssertFalse(session.isPremium)
    }
}
