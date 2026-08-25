import XCTest
@testable import HiAir

final class PaywallLocalizationContractTests: XCTestCase {
    private let paywallKeys = [
        "paywall.required_info",
        "paywall.offer_title_monthly",
        "paywall.offer_title_yearly",
        "paywall.length_month",
        "paywall.length_year",
        "paywall.price_per_month",
        "paywall.service_period",
        "paywall.legal_auto_renew",
        "paywall.terms",
        "paywall.privacy",
        "paywall.restore",
        "paywall.subscribe_monthly",
        "paywall.subscribe_yearly",
        "paywall.nav_title",
        "paywall.title",
        "paywall.subtitle",
    ]

    func testPaywallKeysExistInEnglishAndRussian() {
        for key in paywallKeys {
            for lang in ["en", "ru"] {
                let value = HiAirL10n.t(key, lang: lang)
                XCTAssertFalse(value.isEmpty, "\(key) missing for \(lang)")
                XCTAssertNotEqual(value, key, "Unresolved localization key \(key) for \(lang)")
                XCTAssertFalse(value.hasPrefix("paywall."), "Raw key leaked for \(key)/\(lang): \(value)")
            }
        }
    }

    func testPaywallLegalCopyMentionsAutoRenew() {
        XCTAssertTrue(HiAirL10n.t("paywall.legal_auto_renew", lang: "en").lowercased().contains("auto-renew"))
        XCTAssertTrue(HiAirL10n.t("paywall.legal_auto_renew", lang: "ru").localizedCaseInsensitiveContains("автопродл"))
    }

    @MainActor
    func testSettingsStatusHidesObservabilityLeaks() {
        let model = SettingsViewModel()
        model.statusText = HiAirL10n.t("settings.ai_request_failed", lang: "en")
        XCTAssertFalse(model.showsUserFacingStatus)
        model.statusText = HiAirL10n.t("settings.saved", lang: "en")
        XCTAssertTrue(model.showsUserFacingStatus)
    }
}

final class ReleaseConfigurationLeakTests: XCTestCase {
    func testOperatorChromeGuardIsUITestOnly() {
        XCTAssertFalse(UITestBootstrap.isUITesting)
    }

    func testSettingsSubtitleHasNoOperatorTerms() {
        for lang in ["en", "ru"] {
            let subtitle = HiAirL10n.t("settings.subtitle", lang: lang)
            XCTAssertFalse(subtitle.localizedCaseInsensitiveContains("observability"), lang)
            XCTAssertFalse(subtitle.localizedCaseInsensitiveContains("наблюда"), lang)
            XCTAssertFalse(subtitle.localizedCaseInsensitiveContains("telemetry"), lang)
            XCTAssertFalse(subtitle.localizedCaseInsensitiveContains("debug"), lang)
        }
    }
}

final class ReleaseSourceLeakTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testSettingsOperatorSectionsAreDEBUGOnly() throws {
        let settingsURL = repoRoot
            .appendingPathComponent("mobile/ios/HiAir/Screens/SettingsView.swift")
        let source = try String(contentsOf: settingsURL, encoding: .utf8)
        let markers = [
            "settings.subscription_dev",
            "settings.ai_observability",
            "settings.api_testing",
        ]
        for marker in markers {
            guard let markerRange = source.range(of: marker) else { continue }
            let before = source[..<markerRange.lowerBound]
            let lastDebug = before.range(of: "#if DEBUG", options: .backwards)
            let lastEndif = before.range(of: "#endif", options: .backwards)
            XCTAssertNotNil(lastDebug, "Missing DEBUG guard before \(marker)")
            if let debug = lastDebug, let endif = lastEndif {
                XCTAssertTrue(
                    debug.lowerBound > endif.lowerBound,
                    "Expected \(marker) inside active DEBUG block"
                )
            }
        }
    }

    func testReleaseLeakScriptExists() throws {
        let script = repoRoot.appendingPathComponent("scripts/ops/verify_ios_release_leaks.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: script.path))
    }
}
