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
                HiAirFloatingTabBarHost(selection: $session.selectedTab, items: mainTabItems) {
                    TabView(selection: $session.selectedTab) {
                        DashboardView()
                            .tag(0)
                        DailyPlannerView()
                            .tag(1)
                        InsightsView()
                            .tag(2)
                        SymptomLogView()
                            .tag(3)
                        SettingsView()
                            .tag(4)
                    }
                    .tint(HiAirColors.Cta.gradientStart)
                    .toolbar(.hidden, for: .tabBar)
                    .toolbarBackground(.hidden, for: .tabBar)
                }
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

    private var mainTabItems: [HiAirFloatingTabItem] {
        [
            HiAirFloatingTabItem(
                id: 0,
                title: session.l("tab.dashboard"),
                systemImage: "house",
                selectedSystemImage: "house.fill",
                accessibilityID: HiAirAccessibilityID.Tabs.dashboard
            ),
            HiAirFloatingTabItem(
                id: 1,
                title: session.l("tab.planner"),
                systemImage: "calendar",
                selectedSystemImage: "calendar",
                accessibilityID: HiAirAccessibilityID.Tabs.planner
            ),
            HiAirFloatingTabItem(
                id: 2,
                title: session.l("tab.insights"),
                systemImage: "sparkles",
                selectedSystemImage: "sparkles",
                accessibilityID: HiAirAccessibilityID.Tabs.insights
            ),
            HiAirFloatingTabItem(
                id: 3,
                title: session.l("tab.symptoms"),
                systemImage: "heart",
                selectedSystemImage: "heart.fill",
                accessibilityID: HiAirAccessibilityID.Tabs.symptoms
            ),
            HiAirFloatingTabItem(
                id: 4,
                title: session.l("tab.settings"),
                systemImage: "gearshape",
                selectedSystemImage: "gearshape.fill",
                accessibilityID: HiAirAccessibilityID.Tabs.settings
            ),
        ]
    }
}
