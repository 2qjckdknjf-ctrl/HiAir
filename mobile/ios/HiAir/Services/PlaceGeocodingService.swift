import CoreLocation
import Foundation

/// Reverse-geocodes coordinates to a locality name.
/// Coordinate-keyed, latest-wins, account-aware presentation cache.
/// Does not block Health / Premium / Dashboard work.
actor PlaceGeocodingService {
    static let shared = PlaceGeocodingService()

    private let geocoder = CLGeocoder()
    /// Disk cache of last resolved places keyed by normalized coordinate (not account).
    private let coordCachePrefix = "hiair.place.coord."
    /// Presentation cache owner — never apply without matching account.
    private let presentationNameKey = "hiair.place.presentation.name"
    private let presentationLatKey = "hiair.place.presentation.lat"
    private let presentationLonKey = "hiair.place.presentation.lon"
    private let presentationOwnerKey = "hiair.place.presentation.owner"
    /// Skip re-geocode when moved less than ~1 km (GPS jitter).
    private let reuseDistanceMeters: CLLocationDistance = 1_000

    private var requestGeneration: UInt64 = 0
    private var inFlightKey: String?
    private var inFlight: Task<(key: String, name: String?), Never>?
    private var boundUserId: String = ""

    func bindAccount(userId: String) {
        boundUserId = userId
    }

    /// Logout / account switch: drop presentation and cancel in-flight apply.
    func invalidateSession() {
        requestGeneration &+= 1
        geocoder.cancelGeocode()
        inFlight?.cancel()
        inFlight = nil
        inFlightKey = nil
        boundUserId = ""
        clearPresentationCache()
    }

    func presentationPlaceName(for userId: String) -> String? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: presentationOwnerKey) == userId else { return nil }
        let name = defaults.string(forKey: presentationNameKey)
        return (name?.isEmpty == false) ? name : nil
    }

    func presentationCoordinate(for userId: String) -> (lat: Double, lon: Double)? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: presentationOwnerKey) == userId,
              defaults.object(forKey: presentationLatKey) != nil,
              defaults.object(forKey: presentationLonKey) != nil else { return nil }
        return (defaults.double(forKey: presentationLatKey), defaults.double(forKey: presentationLonKey))
    }

    /// Cached place for UI only when account owns cache and coords reasonably match.
    func reusablePresentationName(userId: String, lat: Double, lon: Double) -> String? {
        guard !userId.isEmpty,
              let name = presentationPlaceName(for: userId),
              let prior = presentationCoordinate(for: userId) else { return nil }
        let a = CLLocation(latitude: prior.lat, longitude: prior.lon)
        let b = CLLocation(latitude: lat, longitude: lon)
        guard a.distance(from: b) <= reuseDistanceMeters else { return nil }
        return name
    }

    /// Returns a place name for the given coordinates (latest-wins).
    func resolvePlaceName(lat: Double, lon: Double, userId: String) async -> String? {
        guard GeoCoordinates.isValid(lat: lat, lon: lon) else { return nil }
        if !userId.isEmpty {
            boundUserId = userId
        }
        let key = Self.coordinateKey(lat: lat, lon: lon)

        if let nearby = reusablePresentationName(userId: userId, lat: lat, lon: lon) {
            return nearby
        }
        if let coordCached = coordinateCacheName(forKey: key) {
            persistPresentation(name: coordCached, lat: lat, lon: lon, userId: userId)
            return coordCached
        }

        // Same coordinate in-flight → deduplicate.
        if let inFlight, inFlightKey == key {
            let result = await inFlight.value
            guard !Task.isCancelled else { return nil }
            return result.name
        }

        // New coordinate → cancel/replace previous request.
        requestGeneration &+= 1
        let generation = requestGeneration
        geocoder.cancelGeocode()
        inFlight?.cancel()

        let expectedUserId = userId
        let task = Task<(key: String, name: String?), Never> {
            let name = await self.geocode(lat: lat, lon: lon)
            return (key, name)
        }
        inFlight = task
        inFlightKey = key
        let result = await task.value

        if inFlight == task {
            inFlight = nil
            inFlightKey = nil
        }

        // Stale / superseded / account mismatch → ignore.
        guard generation == requestGeneration else { return nil }
        guard result.key == key else { return nil }
        guard boundUserId.isEmpty || boundUserId == expectedUserId else { return nil }
        guard !expectedUserId.isEmpty || boundUserId.isEmpty else { return nil }

        if let name = result.name, !name.isEmpty {
            persistCoordinateCache(name: name, key: key)
            persistPresentation(name: name, lat: lat, lon: lon, userId: expectedUserId)
            return name
        }
        // Failure: keep valid same-account presentation if still nearby.
        return reusablePresentationName(userId: expectedUserId, lat: lat, lon: lon)
    }

    private func geocode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            return Self.displayName(from: marks.first)
        } catch {
            return nil
        }
    }

    private func coordinateCacheName(forKey key: String) -> String? {
        let name = UserDefaults.standard.string(forKey: coordCachePrefix + key)
        return (name?.isEmpty == false) ? name : nil
    }

    private func persistCoordinateCache(name: String, key: String) {
        UserDefaults.standard.set(name, forKey: coordCachePrefix + key)
    }

    private func persistPresentation(name: String, lat: Double, lon: Double, userId: String) {
        guard !userId.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: presentationNameKey)
        defaults.set(lat, forKey: presentationLatKey)
        defaults.set(lon, forKey: presentationLonKey)
        defaults.set(userId, forKey: presentationOwnerKey)
    }

    private func clearPresentationCache() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: presentationNameKey)
        defaults.removeObject(forKey: presentationLatKey)
        defaults.removeObject(forKey: presentationLonKey)
        defaults.removeObject(forKey: presentationOwnerKey)
    }

    /// ~110 m grid — stable enough to dedupe GPS jitter without one global city.
    static func coordinateKey(lat: Double, lon: Double) -> String {
        let latBucket = (lat * 1_000).rounded() / 1_000
        let lonBucket = (lon * 1_000).rounded() / 1_000
        return String(format: "%.3f,%.3f", latBucket, lonBucket)
    }

    static func displayName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        let candidates = [
            placemark.locality,
            placemark.subLocality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
        ]
        for value in candidates {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    func clearCacheForTests() {
        clearPresentationCache()
        requestGeneration &+= 1
        inFlight?.cancel()
        inFlight = nil
        inFlightKey = nil
        boundUserId = ""
    }

    func setPresentationForTests(name: String, lat: Double, lon: Double, userId: String) {
        persistPresentation(name: name, lat: lat, lon: lon, userId: userId)
    }

    var debugRequestGeneration: UInt64 { requestGeneration }
}
