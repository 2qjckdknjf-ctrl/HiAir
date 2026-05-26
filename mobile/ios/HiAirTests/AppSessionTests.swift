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

        session.logout()

        XCTAssertEqual(session.userId, "")
        XCTAssertEqual(session.accessToken, "")
        XCTAssertEqual(session.refreshToken, "")
        XCTAssertEqual(session.profileId, "")
        XCTAssertEqual(session.authNotice, "")
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
}
