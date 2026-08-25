import XCTest
@testable import HiAir

final class AppReviewGuidelineCopyTests: XCTestCase {
    func testPermissionPrePromptDoesNotUseAllowOrDeferWording() {
        let languages = ["en", "ru", "es", "it", "fr"]
        for lang in languages {
            let continueLabel = HiAirL10n.t("onboarding.permissions.allow", lang: lang).lowercased()
            XCTAssertFalse(continueLabel.isEmpty, lang)
            XCTAssertNotEqual(continueLabel, "allow", lang)
            XCTAssertFalse(continueLabel.contains("allow"), "\(lang) allow key: \(continueLabel)")

            let later = HiAirL10n.t("onboarding.permissions.later", lang: lang).lowercased()
            XCTAssertFalse(later.contains("later"), "\(lang) later key: \(later)")
            XCTAssertFalse(later.contains("позже"), "\(lang) later key: \(later)")

            let skip = HiAirL10n.t("wearable.consent.skip", lang: lang).lowercased()
            XCTAssertFalse(skip.contains("skip"), "\(lang) skip: \(skip)")
            XCTAssertFalse(skip.contains("пропустить"), skip)
            XCTAssertFalse(skip.contains("omitir"), skip)
        }
        XCTAssertEqual(HiAirL10n.t("onboarding.permissions.allow", lang: "en"), "Continue")
        XCTAssertEqual(HiAirL10n.t("onboarding.permissions.allow", lang: "ru"), "Продолжить")
    }

    func testSubscriptionAndSupportCopyIsPresentInAllLocales() {
        for lang in ["en", "ru", "es", "it", "fr"] {
            XCTAssertFalse(HiAirL10n.t("settings.manage_subscription", lang: lang).isEmpty, lang)
            XCTAssertFalse(HiAirL10n.t("settings.restore_purchases", lang: lang).isEmpty, lang)
            XCTAssertTrue(HiAirL10n.t("settings.support_email", lang: lang).contains("hello@hiair.io"), lang)
            XCTAssertFalse(HiAirL10n.t("paywall.legal_auto_renew", lang: lang).isEmpty, lang)
            XCTAssertFalse(HiAirL10n.t("settings.delete_account_warning", lang: lang).isEmpty, lang)
            let child = HiAirL10n.t("onboarding.for_child", lang: lang).lowercased()
            XCTAssertTrue(child.contains("13"), "\(lang) child persona must state 13+: \(child)")
            XCTAssertFalse(HiAirL10n.t("onboarding.age_requirement", lang: lang).isEmpty, lang)
        }
        XCTAssertEqual(HiAirL10n.t("settings.manage_subscription", lang: "en"), "Manage subscription")
        XCTAssertEqual(HiAirL10n.t("paywall.terms", lang: "en"), "Terms of Use")
        XCTAssertEqual(HiAirL10n.t("paywall.privacy", lang: "en"), "Privacy Policy")
        XCTAssertFalse(HiAirL10n.t("auth.legal", lang: "en").isEmpty)
    }

    func testOAuthCopyDoesNotSendUsersToExternalBrowser() {
        for lang in ["en", "ru", "es", "it", "fr"] {
            let copy = HiAirL10n.t("auth.oauth_continue", lang: lang).lowercased()
            XCTAssertFalse(copy.contains("browser"), lang)
            XCTAssertFalse(copy.contains("браузер"), lang)
            XCTAssertFalse(copy.contains("safari"), lang)
        }
    }
}
