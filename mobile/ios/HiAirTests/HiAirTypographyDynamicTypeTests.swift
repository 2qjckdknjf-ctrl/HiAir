import SwiftUI
import XCTest
@testable import HiAir

final class HiAirTypographyDynamicTypeTests: XCTestCase {
    func testFontScalesWithContentSizeCategory() {
        let medium = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .medium)
        let accessibility = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .accessibilityMedium)
        XCTAssertGreaterThan(accessibility, medium)
    }

    func testScaledFontIncreasesForXXXLarge() {
        let medium = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .medium)
        let xxxLarge = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .extraExtraExtraLarge)
        XCTAssertGreaterThan(xxxLarge, medium)
    }

    func testScaledFontIncreasesForAccessibility3() {
        let medium = HiAirTypography.scaledPointSize(for: .titleMD, sizeCategory: .medium)
        let a11y3 = HiAirTypography.scaledPointSize(for: .titleMD, sizeCategory: .accessibilityMedium)
        XCTAssertGreaterThan(a11y3, medium)
    }

    func testScaledFontIncreasesForAccessibility5() {
        let normal = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .medium)
        let large = HiAirTypography.scaledPointSize(for: .bodyMD, sizeCategory: .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(large, normal)
    }

    func testCategoryChangeProducesDifferentSizes() {
        let first = HiAirTypography.scaledPointSize(for: .bodyLG, sizeCategory: .medium)
        let second = HiAirTypography.scaledPointSize(for: .bodyLG, sizeCategory: .accessibilityLarge)
        XCTAssertNotEqual(first, second)
        XCTAssertGreaterThan(second, first)
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

    func testStageSummaryIncludesOperationId() {
        let summary = AccountDeletionStageLabel.summary(
            ["apple_revoke": "failed"],
            operationId: "op-42"
        )
        XCTAssertTrue(summary.contains("operation_id: op-42"))
        XCTAssertTrue(summary.contains("apple_revoke: failed"))
    }
}
