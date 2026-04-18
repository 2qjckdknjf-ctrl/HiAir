import SwiftUI

@main
struct HiAirApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
        }
    }
}
