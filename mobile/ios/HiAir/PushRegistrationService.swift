import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushRegistrationService {
    static let shared = PushRegistrationService()

    private let apiClient = APIClient.live()

    private init() {}

    func requestAuthorizationAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            guard error == nil, granted else {
                return
            }
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
            return
        }

        Task {
            try? await apiClient.registerDeviceToken(
                userId: userId,
                platform: "ios",
                deviceToken: token,
                profileId: profileId?.isEmpty == true ? nil : profileId,
                accessToken: accessToken
            )
        }
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
