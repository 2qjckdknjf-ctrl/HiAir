import Foundation

/// Launch-argument driven seed for Simulator UI tests. Never enables itself in production launches.
enum UITestBootstrap {
    static let uiTestingArgument = "-UITesting"
    static let mockAPIArgument = "-UITestMockAPI"
    static let skipOnboardingArgument = "-UITestSkipOnboarding"
    static let languageArgumentPrefix = "-UITestLanguage="

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var isMockAPIEnabled: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains(mockAPIArgument)
    }

    static var shouldSkipOnboarding: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains(skipOnboardingArgument)
    }

    static var forcedLanguage: String? {
        guard isUITesting else { return nil }
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(languageArgumentPrefix) })?
            .replacingOccurrences(of: languageArgumentPrefix, with: "")
    }

    static var disableAutoProfileBootstrap: Bool {
        isUITesting && ProcessInfo.processInfo.environment["UITEST_DISABLE_AUTO_PROFILE"] == "1"
    }

    /// Test-only: account-bound durable consent exists with server-inactive semantics.
    /// Requires `-UITesting`. Never active in production launches.
    static var seedWearableDurableInactive: Bool {
        isUITesting
            && ProcessInfo.processInfo.environment["UITEST_SEED_WEARABLE_DURABLE_INACTIVE"] == "1"
    }

    static func prepareBeforeAppLaunch() {
        guard isUITesting else { return }
        if isMockAPIEnabled {
            UITestMockAPIProtocol.reset()
            UITestMockAPIProtocol.isEnabled = true
            let env = ProcessInfo.processInfo.environment
            if let status = Int(env["UITEST_PROFILES_STATUS"] ?? ""), status != 200 {
                UITestMockAPIProtocol.reset(
                    listProfiles: .json(status, object: ["detail": "uitest status \(status)"]),
                    createProfile: .json(status, object: ["detail": "uitest status \(status)"])
                )
            }
            // Inactive-consent UI seed: durable marker + inactive server payload (no upload/delete).
            if env["UITEST_SEED_WEARABLE_DURABLE_INACTIVE"] == "1" {
                UITestMockAPIProtocol.setRoute(
                    method: "GET",
                    path: "/api/v1/wearables/today",
                    response: .json(
                        200,
                        object: [
                            "consent": [
                                "id": "uitest-inactive-consent",
                                "userId": env["UITEST_USER_ID"] ?? "uitest-user",
                                "platform": "ios",
                                "source": "apple_health",
                                "stepsEnabled": true,
                                "heartRateEnabled": true,
                                "restingHeartRateEnabled": true,
                                "isActive": false,
                            ],
                            "dailySummary": NSNull(),
                            "personalLoad": NSNull(),
                        ]
                    )
                )
            }
        }
    }

    @MainActor
    static func apply(to session: AppSession) {
        guard isUITesting else { return }

        if let language = forcedLanguage, !language.isEmpty {
            session.preferredLanguage = language
        }

        let env = ProcessInfo.processInfo.environment
        if env["UITEST_SEED_AUTH"] == "1" {
            session.userId = env["UITEST_USER_ID"] ?? "uitest-user"
            session.email = env["UITEST_EMAIL"] ?? "uitest@example.com"
            session.accessToken = env["UITEST_ACCESS_TOKEN"] ?? "uitest-access-token"
            session.refreshToken = env["UITEST_REFRESH_TOKEN"] ?? "uitest-refresh-token"
        } else {
            // Deterministic unsigned state for auth-screen UI tests.
            session.userId = ""
            session.email = ""
            session.accessToken = ""
            session.refreshToken = ""
            session.profileId = ""
        }

        if shouldSkipOnboarding {
            session.onboardingCompleted = true
        }

        if env["UITEST_SEED_LOCATION"] == "1" {
            let lat = Double(env["UITEST_LAT"] ?? "41.2800") ?? 41.2800
            let lon = Double(env["UITEST_LON"] ?? "1.9760") ?? 1.9760
            session.latitude = lat
            session.longitude = lon
            session.locationSource = .device
            session.displayPlaceName = env["UITEST_PLACE_NAME"] ?? "Castelldefels"
        } else {
            session.latitude = 0
            session.longitude = 0
            session.locationSource = .unknown
            session.displayPlaceName = nil
        }

        if env["UITEST_CLEAR_PROFILE"] == "1" {
            session.profileId = ""
        }

        if let profileId = env["UITEST_PROFILE_ID"], !profileId.isEmpty {
            session.profileId = profileId
        }

        // TF167 harness: retain OS authorization markers without durable account consent,
        // and optionally leave a stale `.connected` presentation for demotion on refresh.
        if env["UITEST_SEED_WEARABLE_OS_AUTH_NO_CONSENT"] == "1", !session.userId.isEmpty {
            let hk = HealthKitService.shared
            hk.seedDurableConsentMarkersForTests(
                userId: session.userId,
                authorized: true,
                consented: false
            )
            hk.bindAccount(userId: session.userId)
            if env["UITEST_SEED_STALE_CONNECTED"] == "1" {
                hk.reportConnectionState(.connected)
            }
        }

        // Durable inactive: account-bound consent marker retained, active=false semantics.
        // Simulates prior OS authorization via UserDefaults markers — no real HealthKit store.
        if seedWearableDurableInactive, !session.userId.isEmpty {
            let hk = HealthKitService.shared
            hk.seedDurableConsentMarkersForTests(
                userId: session.userId,
                authorized: true,
                consented: true
            )
            hk.bindAccount(userId: session.userId)
            // Stale connected enum must not survive as account-connected UI when inactive.
            hk.reportConnectionState(.connected)
        }
    }
}
