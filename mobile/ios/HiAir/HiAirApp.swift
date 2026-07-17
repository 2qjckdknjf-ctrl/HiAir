import SwiftUI

@main
struct HiAirApp: App {
    @StateObject private var session = AppSession()
    private let subscriptionService = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .environmentObject(subscriptionService)
                .onOpenURL { url in
                    Task {
                        _ = await SupabaseAuthService.shared.handleCallbackURL(url)
                    }
                }
        }
    }
}
