import Foundation

enum AnalyticsEventName: String {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case dashboardOpened = "dashboard_opened"
    case morningBriefingOpened = "morning_briefing_opened"
    case shareCardClicked = "share_card_clicked"
    case symptomLogged = "symptom_logged"
    case privacyExportRequested = "privacy_export_requested"
    case privacyDeleteRequested = "privacy_delete_requested"
    case guestModeUsed = "guest_mode_used"
    case feedbackSubmitted = "feedback_submitted"
    case appInstallTracked = "app_install_tracked"
}

@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private static let sessionDefaultsKey = "hiair.analytics.sessionId"
    private let apiClient = APIClient.live()

    private init() {}

    nonisolated static func sessionId() -> String {
        if let existing = UserDefaults.standard.string(forKey: sessionDefaultsKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: sessionDefaultsKey)
        return created
    }

    func track(
        _ event: AnalyticsEventName,
        userId: String? = nil,
        accessToken: String? = nil,
        platform: String = "ios",
        appVersion: String = "0.1.0",
        properties: [String: String] = [:]
    ) {
        let resolvedSessionId = Self.sessionId()
        Task.detached(priority: .utility) { [apiClient] in
            do {
                try await apiClient.ingestAnalyticsEvents(
                    userId: userId,
                    accessToken: accessToken,
                    events: [
                        AnalyticsEventPayload(
                            sessionId: resolvedSessionId,
                            eventName: event.rawValue,
                            platform: platform,
                            appVersion: appVersion,
                            properties: properties
                        )
                    ]
                )
            } catch {
                // Analytics must never break user flows.
            }
        }
    }
}

struct AnalyticsEventPayload: Codable {
    let sessionId: String
    let eventName: String
    let platform: String
    let appVersion: String
    let properties: [String: String]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case eventName = "event_name"
        case platform
        case appVersion = "app_version"
        case properties
    }
}

enum CrashReporter {
    private static var installed = false

    static func install(userIdProvider: @escaping () -> String?, accessTokenProvider: @escaping () -> String?) {
        guard !installed else { return }
        installed = true

        NSSetUncaughtExceptionHandler { exception in
            report(
                message: exception.reason ?? exception.name.rawValue,
                stackTrace: exception.callStackSymbols.joined(separator: "\n"),
                userIdProvider: userIdProvider,
                accessTokenProvider: accessTokenProvider
            )
        }
    }

    private static func report(
        message: String,
        stackTrace: String,
        userIdProvider: @escaping () -> String?,
        accessTokenProvider: @escaping () -> String?
    ) {
        let apiClient = APIClient.live()
        let sessionId = AnalyticsService.sessionId()
        let userId = userIdProvider()
        let accessToken = accessTokenProvider()
        Task.detached(priority: .utility) {
            do {
                try await apiClient.reportCrash(
                    userId: userId,
                    accessToken: accessToken,
                    sessionId: sessionId,
                    message: message,
                    stackTrace: stackTrace,
                    platform: "ios",
                    appVersion: "0.1.0"
                )
            } catch {
                // Best effort only — Firebase Crashlytics can replace this when configured.
            }
        }
    }
}
