import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushRegistrationService {
    static let shared = PushRegistrationService()
    static let lastStatusKey = "push.lastRegistrationStatus"

    private let apiClient = APIClient.live()

    private init() {}

    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard error == nil, granted else {
                UserDefaults.standard.set("denied", forKey: Self.lastStatusKey)
                return
            }
            UserDefaults.standard.set("permission_granted", forKey: Self.lastStatusKey)
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
            return
        }

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
            } catch {
                defaults.set("upload_failed", forKey: Self.lastStatusKey)
            }
        }
    }

    func lastRegistrationStatus() -> String {
        UserDefaults.standard.string(forKey: Self.lastStatusKey) ?? "-"
    }
}

final class HiAirAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushRegistrationService.shared.uploadDeviceToken(deviceToken)
        }
    }
}
