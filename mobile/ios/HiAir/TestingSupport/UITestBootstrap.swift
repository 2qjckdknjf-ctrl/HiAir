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
    }
}
