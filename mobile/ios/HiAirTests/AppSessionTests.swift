import CoreLocation
import XCTest
@testable import HiAir

@MainActor
private final class ImmediateLocationStub: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var serviceState: LocationServiceState = .authorized
    var fetchCalls = 0

    func refreshAuthorizationStatus() {}
    func requestWhenInUseAuthorization() {}
    func openAppSettings() {}

    func fetchCurrentLocation() async throws -> CLLocation {
        fetchCalls += 1
        return CLLocation(latitude: 41.3874, longitude: 2.1686)
    }
}

final class AppSessionTests: XCTestCase {
    func testLocalizationFallbackUsesKeyForUnknownValue() {
        let value = HiAirL10n.t("non.existing.key", lang: "ru")
        XCTAssertEqual(value, "non.existing.key")
    }

    @MainActor
    func testAppSessionLogoutClearsAuthState() {
        let session = AppSession()
        session.userId = "user-1"
        session.accessToken = "access-token"
        session.refreshToken = "refresh-token"
        session.profileId = "profile-1"
        session.authNotice = "notice"
        session.isPremium = true

        session.logout()

        XCTAssertEqual(session.userId, "")
        XCTAssertEqual(session.accessToken, "")
        XCTAssertEqual(session.refreshToken, "")
        XCTAssertEqual(session.profileId, "")
        XCTAssertEqual(session.authNotice, "")
        XCTAssertFalse(session.isPremium)
    }

    @MainActor
    func testApplyEntitlementUnlocksPremium() {
        let session = AppSession()
        let entitlement = UserEntitlementResponse(
            userId: "user-1",
            plan: "premium",
            isPremium: true,
            maxProfiles: 6,
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

    @MainActor
    func testAppSessionFinishOnboardingSetsFlag() {
        let session = AppSession()
        session.onboardingCompleted = false
        session.checklistHidden = true

        session.finishOnboarding()

        XCTAssertTrue(session.onboardingCompleted)
        XCTAssertFalse(session.checklistHidden)
    }

    @MainActor
    func testPrepareSessionSingleFlightReturnsConsistentResult() async {
        let session = AppSession()
        session.userId = "user-prepare"
        // No access token → profile bootstrap skips network.
        session.accessToken = ""
        // Valid coords → skip device location bootstrap path.
        session.latitude = 41.3874
        session.longitude = 2.1686
        let location = ImmediateLocationStub()
        async let first = session.prepareSessionForDataFetch(locationService: location)
        async let second = session.prepareSessionForDataFetch(locationService: location)
        let a = await first
        let b = await second
        XCTAssertEqual(a.profileReady, b.profileReady)
        XCTAssertEqual(a.locationReady, b.locationReady)
        XCTAssertEqual(location.fetchCalls, 0)
    }

    @MainActor
    func testHasValidLocationRejectsNullIsland() {
        let session = AppSession()
        session.latitude = 0
        session.longitude = 0
        XCTAssertFalse(session.hasValidLocation)
        session.latitude = 41.39
        session.longitude = 2.17
        XCTAssertTrue(session.hasValidLocation)
    }
}
