import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var session: AppSession
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if session.userId.isEmpty || session.accessToken.isEmpty {
                AuthView()
                    .accessibilityIdentifier(HiAirAccessibilityID.Auth.root)
            } else if session.onboardingCompleted {
                TabView(selection: $session.selectedTab) {
                    DashboardView()
                        .tag(0)
                        .tabItem {
                            Label(session.l("tab.dashboard"), systemImage: "gauge.medium")
                        }
                        .accessibilityIdentifier(HiAirAccessibilityID.Tabs.dashboard)

                    DailyPlannerView()
                        .tag(1)
                        .tabItem {
                            Label(session.l("tab.planner"), systemImage: "calendar")
                        }
                        .accessibilityIdentifier(HiAirAccessibilityID.Tabs.planner)

                    InsightsView()
                        .tag(2)
                        .tabItem {
                            Label(session.l("tab.insights"), systemImage: "sparkles")
                        }
                        .accessibilityIdentifier(HiAirAccessibilityID.Tabs.insights)

                    SymptomLogView()
                        .tag(3)
                        .tabItem {
                            Label(session.l("tab.symptoms"), systemImage: "heart.text.square")
                        }
                        .accessibilityIdentifier(HiAirAccessibilityID.Tabs.symptoms)

                    SettingsView()
                        .tag(4)
                        .tabItem {
                            Label(session.l("tab.settings"), systemImage: "gearshape")
                        }
                        .accessibilityIdentifier(HiAirAccessibilityID.Tabs.settings)
                }
                .tint(HiAirColors.Cta.gradientStart)
                .toolbarBackground(HiAirLiquidGlass.material(for: .regular), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .task(id: session.userId) {
                    if UITestBootstrap.disableAutoProfileBootstrap {
                        return
                    }
                    _ = await session.prepareSessionForDataFetch()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    guard !session.userId.isEmpty, !session.accessToken.isEmpty else { return }
                    if UITestBootstrap.disableAutoProfileBootstrap {
                        return
                    }
                    Task {
                        await session.refreshOnForeground()
                    }
                }
            } else {
                OnboardingView()
                    .accessibilityIdentifier(HiAirAccessibilityID.Onboarding.root)
            }
        }
        .fullScreenCover(isPresented: $session.showOnboardingFromSettings) {
            OnboardingView(fromSettings: true)
                .environmentObject(session)
                .environmentObject(subscriptionService)
        }
        .fullScreenCover(isPresented: $session.showPaywall) {
            PaywallView()
                .environmentObject(session)
                .environmentObject(subscriptionService)
                .accessibilityIdentifier(HiAirAccessibilityID.Paywall.root)
        }
    }
}
