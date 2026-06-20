import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case value
    case persona
    case location
    case notifications
    case health
    case firstResult
}

struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var dashboardVM = DashboardViewModel()
    @State private var step: OnboardingStep = .welcome
    @State private var persona: String = "adult"
    @State private var sensitivity: String = "medium"
    @State private var latText: String = "41.39"
    @State private var lonText: String = "2.17"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.l("onboarding.title"))
                    .font(.title2.bold())
                Text(stepTitle)
                    .font(.subheadline)
                    .foregroundStyle(HiAirV2Theme.secondaryText)

                switch step {
                case .welcome:
                    onboardingCard(session.l("onboarding.welcome_headline"), session.l("onboarding.welcome_body"))
                    Button(session.l("onboarding.continue")) { step = .value }
                        .buttonStyle(V2PrimaryButtonStyle())
                    Button(session.l("onboarding.continue_guest")) {
                        session.isGuest = true
                        step = .value
                    }
                    .buttonStyle(.bordered)
                    NavigationLink(session.l("auth.title")) {
                        AuthView(onAuthenticated: { step = .value })
                    }

                case .value:
                    onboardingCard(session.l("onboarding.value_headline"), session.l("onboarding.value_body"))
                    nextButton(.persona)

                case .persona:
                    onboardingCard(session.l("onboarding.persona_headline"), session.l("onboarding.persona_body"))
                    Picker(session.l("onboarding.persona"), selection: $persona) {
                        personaLabel("adult", en: "Adult", ru: "Взрослый")
                        personaLabel("child", en: "Child", ru: "Ребенок")
                        personaLabel("elderly", en: "Elderly", ru: "Пожилой")
                        personaLabel("asthma", en: "Asthma", ru: "Астма")
                        personaLabel("allergy", en: "Allergy", ru: "Аллергия")
                        personaLabel("runner", en: "Runner", ru: "Бегун")
                    }
                    .pickerStyle(.menu)
                    Picker(session.l("onboarding.sensitivity"), selection: $sensitivity) {
                        Text(session.preferredLanguage == "en" ? "Low" : "Низкая").tag("low")
                        Text(session.preferredLanguage == "en" ? "Medium" : "Средняя").tag("medium")
                        Text(session.preferredLanguage == "en" ? "High" : "Высокая").tag("high")
                    }
                    .pickerStyle(.segmented)
                    nextButton(.location)

                case .location:
                    onboardingCard(session.l("onboarding.location_headline"), session.l("onboarding.location_body"))
                    TextField(session.l("onboarding.latitude"), text: $latText).textFieldStyle(.roundedBorder)
                    TextField(session.l("onboarding.longitude"), text: $lonText).textFieldStyle(.roundedBorder)
                    nextButton(.notifications)

                case .notifications:
                    onboardingCard(session.l("onboarding.notifications_headline"), session.l("onboarding.notifications_body"))
                    Button(session.l("onboarding.skip")) { step = .health }
                        .buttonStyle(.bordered)
                    nextButton(.health)

                case .health:
                    onboardingCard(session.l("onboarding.health_headline"), session.l("onboarding.health_body"))
                    Text(session.l("onboarding.health_optional"))
                        .font(.footnote)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Button(session.l("onboarding.skip")) {
                        session.healthOptIn = false
                        step = .firstResult
                        loadFirstResult()
                    }
                    .buttonStyle(.bordered)
                    Button(session.l("onboarding.enable_health")) {
                        session.healthOptIn = true
                        step = .firstResult
                        loadFirstResult()
                    }
                    .buttonStyle(V2PrimaryButtonStyle())

                case .firstResult:
                    onboardingCard(session.l("onboarding.first_result_headline"), firstResultText)
                    Button(session.l("onboarding.finish")) { finishOnboarding() }
                        .buttonStyle(V2PrimaryButtonStyle())
                }
            }
            .padding()
        }
        .v2PageBackground()
        .onAppear {
            persona = session.persona
            sensitivity = session.sensitivity
            latText = String(session.latitude)
            lonText = String(session.longitude)
        }
    }

    private var stepTitle: String {
        session.l("onboarding.step.\(stepName)")
    }

    private var stepName: String {
        switch step {
        case .welcome: return "welcome"
        case .value: return "value"
        case .persona: return "persona"
        case .location: return "location"
        case .notifications: return "notifications"
        case .health: return "health"
        case .firstResult: return "first_result"
        }
    }

    private var firstResultText: String {
        if dashboardVM.loading { return session.l("dashboard.loading") }
        if dashboardVM.riskScore != nil {
            return "\(dashboardVM.morningBriefing)\n\n\(session.l("dashboard.current_risk")): \(dashboardVM.riskScore ?? 0) (\(dashboardVM.riskLevel))"
        }
        return dashboardVM.explanation.isEmpty ? session.l("dashboard.error") : dashboardVM.explanation
    }

    private func onboardingCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(HiAirV2Theme.secondaryText)
        }
        .v2Card()
    }

    private func nextButton(_ next: OnboardingStep) -> some View {
        Button(session.l("onboarding.continue")) {
            if step == .persona {
                session.persona = persona
                session.sensitivity = sensitivity
            }
            if step == .location {
                session.latitude = Double(latText) ?? 41.39
                session.longitude = Double(lonText) ?? 2.17
            }
            step = next
            if next == .firstResult { loadFirstResult() }
        }
        .buttonStyle(V2PrimaryButtonStyle())
    }

    private func personaLabel(_ tag: String, en: String, ru: String) -> some View {
        Text(session.preferredLanguage == "en" ? en : ru).tag(tag)
    }

    private func loadFirstResult() {
        session.latitude = Double(latText) ?? session.latitude
        session.longitude = Double(lonText) ?? session.longitude
        session.persona = persona
        Task {
            await dashboardVM.refresh(
                userId: session.userId,
                accessToken: session.accessToken,
                profileId: session.profileId.isEmpty ? nil : session.profileId,
                persona: session.persona,
                lat: session.latitude,
                lon: session.longitude,
                language: session.preferredLanguage,
                isGuest: session.isGuest
            )
        }
    }

    private func finishOnboarding() {
        session.persona = persona
        session.sensitivity = sensitivity
        session.latitude = Double(latText) ?? session.latitude
        session.longitude = Double(lonText) ?? session.longitude
        session.onboardingCompleted = true
    }
}
