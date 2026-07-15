import SwiftUI

@main
struct HiAirApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .onAppear {
                    CrashReporter.install(
                        userIdProvider: {
                            session.userId.isEmpty ? nil : session.userId
                        },
                        accessTokenProvider: {
                            session.accessToken.isEmpty ? nil : session.accessToken
                        }
                    )
                    AnalyticsService.shared.track(
                        .appInstallTracked,
                        userId: session.userId.isEmpty ? nil : session.userId,
                        accessToken: session.accessToken.isEmpty ? nil : session.accessToken
                    )
                }
        }
    }
}
