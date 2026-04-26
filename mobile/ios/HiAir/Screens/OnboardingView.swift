import CoreLocation
import SwiftUI

@MainActor
final class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var statusKey = "-"

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
            statusKey = "onboarding.location_permission_requesting"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            statusKey = "onboarding.location_updating"
            manager.requestLocation()
        case .denied, .restricted:
            statusKey = "onboarding.location_permission_disabled"
        @unknown default:
            statusKey = "onboarding.location_permission_unavailable"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            statusKey = "onboarding.location_updating"
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            statusKey = "onboarding.location_unavailable"
            return
        }
        onUpdate?(coordinate)
        statusKey = "onboarding.location_updated"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusKey = "onboarding.location_update_failed"
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
                Text(session.l("settings.persona_adult")).tag("adult")
                Text(session.l("settings.persona_child")).tag("child")
                Text(session.l("settings.persona_elderly")).tag("elderly")
                Text(session.l("settings.persona_asthma")).tag("asthma")
                Text(session.l("settings.persona_allergy")).tag("allergy")
                Text(session.l("settings.persona_runner")).tag("runner")
            }
            .pickerStyle(.menu)

            Picker(session.l("onboarding.sensitivity"), selection: $sensitivity) {
                Text(session.l("onboarding.sensitivity_low")).tag("low")
                Text(session.l("onboarding.sensitivity_medium")).tag("medium")
                Text(session.l("onboarding.sensitivity_high")).tag("high")
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
        .onChange(of: locationManager.statusKey) { value in
            if value != "-" {
                statusText = session.l(value)
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
