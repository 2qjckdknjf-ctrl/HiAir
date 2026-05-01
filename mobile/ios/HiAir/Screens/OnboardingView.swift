import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @State private var persona: String = "adult"
    @State private var sensitivity: String = "medium"
    @State private var latText: String = "41.39"
    @State private var lonText: String = "2.17"
    @State private var profileIdText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AuroraTokens.Spacing.md) {
                Text(session.l("onboarding.title"))
                    .font(AuroraTokens.Typography.displayLG)
                    .foregroundStyle(HiAirV2Theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text(session.l("onboarding.persona"))
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Picker(session.l("onboarding.persona"), selection: $persona) {
                        Text(session.preferredLanguage == "en" ? "Adult" : "Взрослый").tag("adult")
                        Text(session.preferredLanguage == "en" ? "Child" : "Ребенок").tag("child")
                        Text(session.preferredLanguage == "en" ? "Elderly" : "Пожилой").tag("elderly")
                        Text(session.preferredLanguage == "en" ? "Asthma" : "Астма").tag("asthma")
                        Text(session.preferredLanguage == "en" ? "Allergy" : "Аллергия").tag("allergy")
                        Text(session.preferredLanguage == "en" ? "Runner" : "Бегун").tag("runner")
                    }
                    .pickerStyle(.menu)

                    Text(session.l("onboarding.sensitivity"))
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                    Picker(session.l("onboarding.sensitivity"), selection: $sensitivity) {
                        Text(session.preferredLanguage == "en" ? "Low" : "Низкая").tag("low")
                        Text(session.preferredLanguage == "en" ? "Medium" : "Средняя").tag("medium")
                        Text(session.preferredLanguage == "en" ? "High" : "Высокая").tag("high")
                    }
                    .pickerStyle(.segmented)

                    Group {
                        TextField(session.l("onboarding.latitude"), text: $latText)
                        TextField(session.l("onboarding.longitude"), text: $lonText)
                        TextField(session.l("onboarding.profile_id"), text: $profileIdText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(HiAirV2Theme.primaryText)
                }
                .v2Card()

                Button(session.l("onboarding.continue")) {
                    let lat = Double(latText) ?? 41.39
                    let lon = Double(lonText) ?? 2.17
                    session.persona = persona
                    session.sensitivity = sensitivity
                    session.latitude = lat
                    session.longitude = lon
                    session.profileId = profileIdText.trimmingCharacters(in: .whitespacesAndNewlines)
                    session.onboardingCompleted = true
                }
                .buttonStyle(V2PrimaryButtonStyle())
            }
            .padding(16)
        }
        .v2PageBackground()
        .onAppear {
            persona = session.persona
            sensitivity = session.sensitivity
            latText = String(session.latitude)
            lonText = String(session.longitude)
            profileIdText = session.profileId
        }
    }
}
