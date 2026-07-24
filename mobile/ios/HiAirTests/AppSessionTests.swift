import XCTest
@testable import HiAir

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
        session.accessToken = "token"
        // Without network/location, prepare should complete (partial) and not hang.
        async let first = session.prepareSessionForDataFetch()
        async let second = session.prepareSessionForDataFetch()
        let a = await first
        let b = await second
        XCTAssertEqual(a.profileReady, b.profileReady)
        XCTAssertEqual(a.locationReady, b.locationReady)
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
