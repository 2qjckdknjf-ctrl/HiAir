import XCTest
@testable import HiAir

final class RiskBreakdownParsingTests: XCTestCase {
    func testRiskBreakdownResponseDecodesSnakeCase() throws {
        let json = """
        {
          "profile_id": "p1",
          "total_score": 58,
          "risk_level": "medium",
          "factors": [
            {"key": "heat", "label_ru": "жара", "label_en": "heat", "points": 24}
          ]
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(RiskBreakdownResponse.self, from: json)
        XCTAssertEqual(decoded.totalScore, 58)
        XCTAssertEqual(decoded.factors.first?.points, 24)
    }
}
