import SwiftUI
import XCTest
@testable import HiAir

final class HiAirTypographyDynamicTypeTests: XCTestCase {
    func testFontScalesWithContentSizeCategory() {
        let medium = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .medium)
        let accessibility = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .accessibilityMedium)
        XCTAssertGreaterThan(accessibility, medium)
    }

    func testScaledFontIncreasesForAccessibility5() {
        let normal = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .medium)
        let large = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(large, normal)
    }
}

final class AccountDeletionModelsTests: XCTestCase {
    func testParsesStructuredDeletionError() throws {
        let json = """
        {"detail":{"message":"missing code","operation_id":"op-1","stages":{"apple_revoke":"failed"},"recovery_hint":"Retry"}}
        """.data(using: .utf8)!
        let error = AccountDeletionAPIError.parse(statusCode: 422, data: json)
        XCTAssertEqual(error.operationId, "op-1")
        XCTAssertEqual(error.stages["apple_revoke"], "failed")
        XCTAssertEqual(error.recoveryHint, "Retry")
    }
}
