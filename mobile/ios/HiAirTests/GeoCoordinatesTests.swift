import CoreLocation
import XCTest
@testable import HiAir

final class GeoCoordinatesTests: XCTestCase {
    func testValidCoordinates() {
        XCTAssertTrue(GeoCoordinates.isValid(lat: 48.85, lon: 2.35))
    }

    func testRejectsNullIsland() {
        XCTAssertFalse(GeoCoordinates.isValid(lat: 0, lon: 0))
    }

    func testRejectsOutOfRange() {
        XCTAssertFalse(GeoCoordinates.isValid(lat: 91, lon: 2))
        XCTAssertFalse(GeoCoordinates.isValid(lat: 41, lon: 181))
    }

    func testValidLocationObject() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
            altitude: 0,
            horizontalAccuracy: 40,
            verticalAccuracy: 0,
            timestamp: Date()
        )
        XCTAssertTrue(GeoCoordinates.isValid(location))
    }

    func testRejectsStaleLocation() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
            altitude: 0,
            horizontalAccuracy: 40,
            verticalAccuracy: 0,
            timestamp: Date(timeIntervalSinceNow: -600)
        )
        XCTAssertFalse(GeoCoordinates.isValid(location))
    }
}
