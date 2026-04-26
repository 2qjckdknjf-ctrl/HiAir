import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class PushRegistrationService {
    static let shared = PushRegistrationService()
    static let lastStatusKey = "push.lastRegistrationStatus"

    private let apiClient = APIClient.live()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HiAir", category: "push")

    private init() {}

    func requestAuthorizationAndRegister() {
        Self.logger.info("Push: requesting notification authorization")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard error == nil, granted else {
                UserDefaults.standard.set("denied", forKey: Self.lastStatusKey)
                if let error {
                    Self.logger.warning("Push: permission denied or error — \(error.localizedDescription, privacy: .public)")
                } else {
                    Self.logger.warning("Push: permission denied by user")
                }
                return
            }
            UserDefaults.standard.set("permission_granted", forKey: Self.lastStatusKey)
            Self.logger.info("Push: permission granted; calling registerForRemoteNotifications")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func uploadDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let defaults = UserDefaults.standard
        let userId = defaults.string(forKey: AppSession.Keys.userId) ?? ""
        let profileId = defaults.string(forKey: AppSession.Keys.profileId)
        let accessToken = KeychainStore.read(AppSession.Keys.accessToken) ?? ""

        guard !userId.isEmpty, !accessToken.isEmpty else {
            defaults.set("missing_auth", forKey: Self.lastStatusKey)
            Self.logger.warning("Push: token upload skipped — missing user id or bearer token (user not signed in)")
            return
        }

        Self.logger.info("Push: token upload attempted (platform=ios, token prefix=\(String(token.prefix(8)), privacy: .public)…)")
        Task {
            do {
                try await apiClient.registerDeviceToken(
                    userId: userId,
                    platform: "ios",
                    deviceToken: token,
                    profileId: profileId?.isEmpty == true ? nil : profileId,
                    accessToken: accessToken
                )
                defaults.set("uploaded", forKey: Self.lastStatusKey)
                Self.logger.info("Push: token registered with backend (/api/notifications/device-token)")
            } catch {
                defaults.set("upload_failed", forKey: Self.lastStatusKey)
                Self.logger.error("Push: token upload failed — \(String(describing: error), privacy: .public)")
            }
        }
    }

    func lastRegistrationStatus() -> String {
        UserDefaults.standard.string(forKey: Self.lastStatusKey) ?? "-"
    }
}

final class HiAirAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushRegistrationService.shared.uploadDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HiAir", category: "push")
        log.error("Push: didFailToRegisterForRemoteNotifications — \(error.localizedDescription, privacy: .public)")
        UserDefaults.standard.set("apns_register_failed", forKey: PushRegistrationService.lastStatusKey)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "HiAir", category: "push")
        log.info("Push: willPresent notification id=\(notification.request.identifier, privacy: .public)")
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
