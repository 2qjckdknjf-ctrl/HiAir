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
