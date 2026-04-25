import SwiftUI

@main
struct HiAirApp: App {
    @UIApplicationDelegateAdaptor(HiAirAppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
        }
    }
}
