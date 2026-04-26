import CoreLocation
import SwiftUI

@MainActor
final class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var statusText = "-"

    private let manager = CLLocationManager()
    private var onUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation(onUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onUpdate = onUpdate
        switch manager.authorizationStatus {
        case .notDetermined:
            statusText = "Requesting location permission..."
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Updating location..."
            manager.requestLocation()
        case .denied, .restricted:
            statusText = "Location permission is disabled."
        @unknown default:
            statusText = "Location permission is unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            statusText = "Updating location..."
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            statusText = "Location unavailable."
            return
        }
        onUpdate?(coordinate)
        statusText = "Location updated."
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusText = "Location update failed."
    }
}

struct OnboardingView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var locationManager = OnboardingLocationManager()
    @State private var persona: String = "adult"
    @State private var sensitivity: String = "medium"
    @State private var latText: String = "41.39"
    @State private var lonText: String = "2.17"
    @State private var statusText: String = "-"
    @State private var loading = false
    private let apiClient = APIClient.live()

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

            Button(session.l("onboarding.use_current_location")) {
                locationManager.requestCurrentLocation { coordinate in
                    latText = String(format: "%.5f", coordinate.latitude)
                    lonText = String(format: "%.5f", coordinate.longitude)
                    statusText = session.l("onboarding.location_updated")
                }
            }
            .buttonStyle(.bordered)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(loading ? session.l("onboarding.creating_profile") : session.l("onboarding.continue")) {
                Task { await createProfileAndContinue() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(loading)
        }
        .padding()
        .onAppear {
            persona = session.persona
            sensitivity = session.sensitivity
            latText = String(session.latitude)
            lonText = String(session.longitude)
        }
        .onChange(of: locationManager.statusText) { value in
            if value != "-" {
                statusText = value
            }
        }
    }

    private func createProfileAndContinue() async {
        guard !session.userId.isEmpty, !session.accessToken.isEmpty else {
            statusText = session.l("onboarding.auth_required")
            return
        }
        let lat = Double(latText) ?? 41.39
        let lon = Double(lonText) ?? 2.17
        loading = true
        defer { loading = false }
        do {
            let profile = try await apiClient.createProfile(
                ProfileCreateRequest(
                    personaType: persona,
                    sensitivityLevel: sensitivity,
                    homeLat: lat,
                    homeLon: lon
                ),
                userId: session.userId,
                accessToken: session.accessToken
            )
            session.persona = persona
            session.sensitivity = sensitivity
            session.latitude = lat
            session.longitude = lon
            session.profileId = profile.id
            session.onboardingCompleted = true
            statusText = session.l("onboarding.profile_created")
        } catch {
            statusText = session.l("onboarding.profile_create_failed")
        }
    }
}
