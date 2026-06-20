import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        Group {
            if !session.onboardingCompleted {
                OnboardingView()
            } else if !session.isGuest && (session.userId.isEmpty || session.accessToken.isEmpty) {
                AuthView()
            } else {
                TabView(selection: $session.selectedTab) {
                    DashboardView()
                        .tag(0)
                        .tabItem {
                            Label(session.l("tab.dashboard"), systemImage: "gauge.medium")
                        }

                    DailyPlannerView()
                        .tag(1)
                        .tabItem {
                            Label(session.l("tab.planner"), systemImage: "calendar")
                        }

                    SymptomLogView()
                        .tag(2)
                        .tabItem {
                            Label(session.l("tab.symptoms"), systemImage: "heart.text.square")
                        }

                    SettingsView()
                        .tag(3)
                        .tabItem {
                            Label(session.l("tab.settings"), systemImage: "gearshape")
                        }
                }
                .tint(HiAirV2Theme.accentStart)
            }
        }
    }
}
