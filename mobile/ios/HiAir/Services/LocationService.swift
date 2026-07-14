import CoreLocation
import Foundation
import UIKit

enum LocationSource: String, Equatable {
    case device
    case manual
    case cached
    case unknown
}

enum GeoCoordinates {
    static let maxAgeSeconds: TimeInterval = 300
    static let maxHorizontalAccuracyMeters = CLLocationDistance(5000)

    static func isValid(lat: Double, lon: Double) -> Bool {
        guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else {
            return false
        }
        guard !(lat == 0 && lon == 0) else {
            return false
        }
        return true
    }

    static func isValid(_ location: CLLocation) -> Bool {
        guard isValid(lat: location.coordinate.latitude, lon: location.coordinate.longitude) else {
            return false
        }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxHorizontalAccuracyMeters else {
            return false
        }
        guard abs(location.timestamp.timeIntervalSinceNow) <= maxAgeSeconds else {
            return false
        }
        return true
    }

    static func accuracyBucket(for location: CLLocation) -> String {
        switch location.horizontalAccuracy {
        case ..<50:
            return "high"
        case ..<500:
            return "medium"
        default:
            return "low"
        }
    }
}

enum LocationServiceState: Equatable {
    case idle
    case requestingPermission
    case authorized
    case locating
    case success
    case denied
    case restricted
    case servicesDisabled
    case timeout
    case error
}

enum LocationServiceError: Error, Equatable {
    case denied
    case restricted
    case servicesDisabled
    case timeout
    case invalidCoordinate
    case underlying(String)
}

extension Notification.Name {
    static let profileLocationDidUpdate = Notification.Name("ProfileLocationDidUpdate")
}

protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var serviceState: LocationServiceState { get }
    func refreshAuthorizationStatus()
    func requestWhenInUseAuthorization()
    func fetchCurrentLocation() async throws -> CLLocation
    func openAppSettings()
}

@MainActor
final class LocationService: NSObject, ObservableObject, LocationProviding {
    static let shared = LocationService()

    @Published private(set) var serviceState: LocationServiceState = .idle
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var timeoutTask: Task<Void, Never>?
    private let locationTimeoutSeconds: TimeInterval = 20

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshAuthorizationStatus()
    }

    init(manager: CLLocationManager) {
        self.manager = manager
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
        updateStateFromAuthorization()
    }

    func requestWhenInUseAuthorization() {
        serviceState = .requestingPermission
        manager.requestWhenInUseAuthorization()
    }

    func fetchCurrentLocation() async throws -> CLLocation {
        refreshAuthorizationStatus()
        guard CLLocationManager.locationServicesEnabled() else {
            serviceState = .servicesDisabled
            throw LocationServiceError.servicesDisabled
        }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied:
            serviceState = .denied
            throw LocationServiceError.denied
        case .restricted:
            serviceState = .restricted
            throw LocationServiceError.restricted
        case .notDetermined:
            requestWhenInUseAuthorization()
            throw LocationServiceError.denied
        @unknown default:
            serviceState = .error
            throw LocationServiceError.underlying("unknown authorization")
        }

        serviceState = .locating
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation?.resume(throwing: LocationServiceError.timeout)
            locationContinuation = continuation
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.locationTimeoutSeconds ?? 20) * 1_000_000_000)
                await MainActor.run {
                    guard let self, self.locationContinuation != nil else { return }
                    self.finishLocationFetch(with: .failure(LocationServiceError.timeout))
                }
            }
            manager.requestLocation()
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func updateStateFromAuthorization() {
        guard CLLocationManager.locationServicesEnabled() else {
            serviceState = .servicesDisabled
            return
        }
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if serviceState != .locating {
                serviceState = .authorized
            }
        case .denied:
            serviceState = .denied
        case .restricted:
            serviceState = .restricted
        case .notDetermined:
            if serviceState != .requestingPermission {
                serviceState = .idle
            }
        @unknown default:
            serviceState = .error
        }
    }

    private func finishLocationFetch(with result: Result<CLLocation, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let continuation = locationContinuation
        locationContinuation = nil
        switch result {
        case let .success(location):
            if GeoCoordinates.isValid(location) {
                serviceState = .success
                ProductAnalytics.track(
                    "location_fetch_success",
                    properties: [
                        "source": LocationSource.device.rawValue,
                        "accuracy_bucket": GeoCoordinates.accuracyBucket(for: location),
                    ]
                )
                continuation?.resume(returning: location)
            } else {
                serviceState = .error
                ProductAnalytics.track("location_fetch_failed", properties: ["reason": "invalid_coordinate"])
                continuation?.resume(throwing: LocationServiceError.invalidCoordinate)
            }
        case let .failure(error):
            if let serviceError = error as? LocationServiceError, serviceError == .timeout {
                serviceState = .timeout
            } else {
                serviceState = .error
            }
            ProductAnalytics.track("location_fetch_failed", properties: ["reason": "error"])
            continuation?.resume(throwing: error)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            refreshAuthorizationStatus()
            ProductAnalytics.track(
                "location_permission_status",
                properties: ["status": String(describing: authorizationStatus)]
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            finishLocationFetch(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            finishLocationFetch(with: .failure(LocationServiceError.underlying(error.localizedDescription)))
        }
    }
}
