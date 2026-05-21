import XCTest
@testable import HiAir

final class AppSessionTests: XCTestCase {
    func testLocalizationFallbackUsesKeyForUnknownValue() {
        let value = HiAirL10n.t("non.existing.key", lang: "ru")
        XCTAssertEqual(value, "non.existing.key")
    }
}
