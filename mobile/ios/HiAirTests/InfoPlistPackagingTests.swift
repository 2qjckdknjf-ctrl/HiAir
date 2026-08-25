import Foundation
import XCTest
@testable import HiAir

/// Guards Release packaging: source Info.plist must derive versions from build settings,
/// and the built app product must expand them (no unresolved `$(...)`).
final class InfoPlistPackagingTests: XCTestCase {
    func testSourceInfoPlistVersionsTrackBuildSettings() throws {
        let sourcePlist = try Self.locateSourceInfoPlist()
        let data = try Data(contentsOf: sourcePlist)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dict = object as? [String: Any] else {
            return XCTFail("Info.plist root must be a dictionary")
        }
        XCTAssertEqual(
            dict["CFBundleShortVersionString"] as? String,
            "$(MARKETING_VERSION)",
            "source Info.plist must not hard-code marketing version (ASC/TF regression risk)"
        )
        XCTAssertEqual(
            dict["CFBundleVersion"] as? String,
            "$(CURRENT_PROJECT_VERSION)",
            "source Info.plist must not hard-code build number (ASC/TF regression risk)"
        )
        XCTAssertEqual(dict["CFBundleIdentifier"] as? String, "$(PRODUCT_BUNDLE_IDENTIFIER)")
        XCTAssertNotNil(dict["SUPABASE_URL"] as? String)
        XCTAssertNotNil(dict["SUPABASE_ANON_KEY"] as? String)
        XCTAssertNotNil(dict["API_BASE_URL"] as? String)
        let urlTypes = dict["CFBundleURLTypes"] as? [[String: Any]]
        let schemes = urlTypes?.first?["CFBundleURLSchemes"] as? [String]
        XCTAssertEqual(schemes, ["hiair"])
        XCTAssertEqual(dict["LSApplicationQueriesSchemes"] as? [String], ["x-apple-health"])
    }

    func testBuiltProductInfoPlistHasExpandedRuntimeKeys() throws {
        let info = Bundle.main.infoDictionary
        XCTAssertEqual(info?["CFBundleIdentifier"] as? String, "com.hiair.app")
        let marketing = try XCTUnwrap(info?["CFBundleShortVersionString"] as? String)
        let build = try XCTUnwrap(info?["CFBundleVersion"] as? String)
        XCTAssertFalse(marketing.contains("$("), "unresolved marketing version: \(marketing)")
        XCTAssertFalse(build.contains("$("), "unresolved build number: \(build)")
        XCTAssertFalse(marketing.isEmpty)
        XCTAssertFalse(build.isEmpty)
        let expectedMarketing = try Self.marketingVersionFromProjectYml()
        XCTAssertEqual(
            marketing,
            expectedMarketing,
            "product must expand MARKETING_VERSION (\(expectedMarketing)) from build settings"
        )
        XCTAssertNotEqual(build, "1", "Release product must use CURRENT_PROJECT_VERSION, not plist default 1")

        let supabaseURL = try XCTUnwrap(info?["SUPABASE_URL"] as? String)
        let apiBase = try XCTUnwrap(info?["API_BASE_URL"] as? String)
        let anon = try XCTUnwrap(info?["SUPABASE_ANON_KEY"] as? String)
        XCTAssertFalse(supabaseURL.contains("$("))
        XCTAssertFalse(apiBase.contains("$("))
        XCTAssertFalse(anon.contains("$("))
        XCTAssertFalse(anon.lowercased().contains("service_role"))
        XCTAssertFalse(anon.contains("sb_secret"))

        let urlTypes = info?["CFBundleURLTypes"] as? [[String: Any]]
        let schemes = urlTypes?.compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 } ?? []
        XCTAssertTrue(schemes.contains("hiair"), "auth URL scheme missing from product Info.plist")
        let queries = info?["LSApplicationQueriesSchemes"] as? [String] ?? []
        XCTAssertTrue(queries.contains("x-apple-health"))

        XCTAssertNotNil(info?["NSHealthShareUsageDescription"] as? String)
        XCTAssertNotNil(info?["NSHealthUpdateUsageDescription"] as? String)
        XCTAssertNotNil(info?["NSLocationWhenInUseUsageDescription"] as? String)
    }

    private static func locateSourceInfoPlist() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("HiAir/Info.plist")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("HiAir/Info.plist not found relative to test source")
    }

    private static func marketingVersionFromProjectYml() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("project.yml")
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            let text = try String(contentsOf: candidate, encoding: .utf8)
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("MARKETING_VERSION:") else { continue }
                let raw = trimmed.replacingOccurrences(of: "MARKETING_VERSION:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !raw.isEmpty { return raw }
            }
        }
        throw XCTSkip("MARKETING_VERSION not found in project.yml")
    }
}
