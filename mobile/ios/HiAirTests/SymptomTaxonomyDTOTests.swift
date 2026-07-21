import XCTest
@testable import HiAir

final class SymptomTaxonomyDTOTests: XCTestCase {
    func testDecodesSeverityNoticeAliasFromProductionShape() throws {
        let json = """
        {
          "consentVersion": "health-intelligence-v1",
          "severityNotice": "Wellness notice",
          "categories": [
            {
              "id": "respiratory",
              "label": "Breathing",
              "symptoms": [
                {"symptomType": "cough", "label": "Cough", "redFlag": false},
                {"symptomType": "shortness_of_breath", "label": "Shortness of breath", "redFlag": true}
              ]
            }
          ],
          "count": 2
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SymptomTaxonomyDTO.self, from: json)
        XCTAssertEqual(decoded.safetyNotice, "Wellness notice")
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.categories.first?.symptoms.count, 2)
        XCTAssertEqual(decoded.categories.first?.symptoms.first?.label, "Cough")
    }

    func testDecodesSafetyNoticePreferred() throws {
        let json = """
        {
          "consentVersion": "health-intelligence-v1",
          "safetyNotice": "Preferred",
          "severityNotice": "Legacy",
          "categories": [
            {
              "id": "general",
              "label": "General",
              "symptoms": [
                {"symptomType": "fatigue", "label": "Fatigue", "redFlag": false}
              ]
            }
          ],
          "count": 1
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SymptomTaxonomyDTO.self, from: json)
        XCTAssertEqual(decoded.safetyNotice, "Preferred")
    }

    func testRejectsMissingNotice() {
        let json = """
        {
          "categories": [],
          "count": 0
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(SymptomTaxonomyDTO.self, from: json))
    }
}
