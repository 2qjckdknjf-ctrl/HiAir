import CoreLocation
import Foundation

/// Reverse-geocodes coordinates to a locality name with single-flight + disk cache.
/// Does not block Health / Premium / Dashboard work.
actor PlaceGeocodingService {
    static let shared = PlaceGeocodingService()

    private let geocoder = CLGeocoder()
    private let cacheKey = "hiair.place.displayName"
    private let cacheLatKey = "hiair.place.lat"
    private let cacheLonKey = "hiair.place.lon"
    /// Skip re-geocode when moved less than ~1 km.
    private let reuseDistanceMeters: CLLocationDistance = 1_000

    private var inFlight: Task<String?, Never>?

    func cachedPlaceName() -> String? {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: cacheKey)
        return (name?.isEmpty == false) ? name : nil
    }

    func cachedCoordinate() -> (lat: Double, lon: Double)? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: cacheLatKey) != nil,
              defaults.object(forKey: cacheLonKey) != nil else { return nil }
        return (defaults.double(forKey: cacheLatKey), defaults.double(forKey: cacheLonKey))
    }

    /// Returns a place name for the given coordinates (cache hit or CLGeocoder).
    func resolvePlaceName(lat: Double, lon: Double) async -> String? {
        if let cached = reuseCachedIfNearby(lat: lat, lon: lon) {
            return cached
        }
        if let inFlight {
            return await inFlight.value
        }
        let task = Task<String?, Never> {
            await self.geocode(lat: lat, lon: lon)
        }
        inFlight = task
        let name = await task.value
        if inFlight == task {
            inFlight = nil
        }
        return name
    }

    private func reuseCachedIfNearby(lat: Double, lon: Double) -> String? {
        guard let name = cachedPlaceName(),
              let prior = cachedCoordinate() else { return nil }
        let a = CLLocation(latitude: prior.lat, longitude: prior.lon)
        let b = CLLocation(latitude: lat, longitude: lon)
        if a.distance(from: b) <= reuseDistanceMeters {
            return name
        }
        return nil
    }

    private func geocode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            let name = Self.displayName(from: marks.first)
            if let name {
                persist(name: name, lat: lat, lon: lon)
            }
            return name
        } catch {
            return cachedPlaceName()
        }
    }

    private func persist(name: String, lat: Double, lon: Double) {
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: cacheKey)
        defaults.set(lat, forKey: cacheLatKey)
        defaults.set(lon, forKey: cacheLonKey)
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

    #if DEBUG
    func clearCacheForTests() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: cacheKey)
        defaults.removeObject(forKey: cacheLatKey)
        defaults.removeObject(forKey: cacheLonKey)
    }
    #endif
}
