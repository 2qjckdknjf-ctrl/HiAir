import SwiftUI

@main
struct HiAirApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .onOpenURL { url in
                    Task {
                        _ = await SupabaseAuthService.shared.handleCallbackURL(url)
                    }
                }
        }
    }
}
