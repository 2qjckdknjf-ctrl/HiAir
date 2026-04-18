import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @State private var persona: String = "adult"
    @State private var sensitivity: String = "medium"
    @State private var latText: String = "41.39"
    @State private var lonText: String = "2.17"
    @State private var profileIdText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(session.l("onboarding.title"))
                .font(.title2)
                .bold()

            Picker(session.l("onboarding.persona"), selection: $persona) {
                Text(session.preferredLanguage == "en" ? "Adult" : "Взрослый").tag("adult")
                Text(session.preferredLanguage == "en" ? "Child" : "Ребенок").tag("child")
                Text(session.preferredLanguage == "en" ? "Elderly" : "Пожилой").tag("elderly")
                Text(session.preferredLanguage == "en" ? "Asthma" : "Астма").tag("asthma")
                Text(session.preferredLanguage == "en" ? "Allergy" : "Аллергия").tag("allergy")
                Text(session.preferredLanguage == "en" ? "Runner" : "Бегун").tag("runner")
            }
            .pickerStyle(.menu)

            Picker(session.l("onboarding.sensitivity"), selection: $sensitivity) {
                Text(session.preferredLanguage == "en" ? "Low" : "Низкая").tag("low")
                Text(session.preferredLanguage == "en" ? "Medium" : "Средняя").tag("medium")
                Text(session.preferredLanguage == "en" ? "High" : "Высокая").tag("high")
            }
            .pickerStyle(.segmented)

            TextField(session.l("onboarding.latitude"), text: $latText)
                .textFieldStyle(.roundedBorder)
            TextField(session.l("onboarding.longitude"), text: $lonText)
                .textFieldStyle(.roundedBorder)

            TextField(session.l("onboarding.profile_id"), text: $profileIdText)
                .textFieldStyle(.roundedBorder)

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
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            persona = session.persona
            sensitivity = session.sensitivity
            latText = String(session.latitude)
            lonText = String(session.longitude)
            profileIdText = session.profileId
        }
    }
}
