import XCTest
@testable import HiAir

final class HiAirDeepGlassTokenTests: XCTestCase {
    func testHeroGlassIsBrighterThanPassive() {
        XCTAssertGreaterThan(HiAirGlassProminence.hero.fillAlpha, HiAirGlassProminence.standard.fillAlpha)
        XCTAssertGreaterThan(HiAirGlassProminence.standard.fillAlpha, HiAirGlassProminence.passive.fillAlpha)
        XCTAssertGreaterThan(HiAirGlassProminence.hero.outerGlowAlpha, HiAirGlassProminence.passive.outerGlowAlpha)
    }

    func testRiskSemanticColorsStayDistinct() {
        let low = HiAirRiskStyle.color(for: "low")
        let moderate = HiAirRiskStyle.color(for: "moderate")
        let high = HiAirRiskStyle.color(for: "high")
        let severe = HiAirRiskStyle.color(for: "very_high")
        XCTAssertNotEqual(low, moderate)
        XCTAssertNotEqual(moderate, high)
        XCTAssertNotEqual(high, severe)
    }

    func testCtaUsesThreeStopSpectrum() {
        XCTAssertEqual(HiAirRadius.cta, 20)
        XCTAssertEqual(HiAirRadius.hero, 24)
        XCTAssertEqual(HiAirRadius.tabBar, 30)
        XCTAssertEqual(HiAirMotion.pressScale, 0.978, accuracy: 0.001)
    }

    func testGlassEdgesStaySharperThanGlowWash() {
        XCTAssertGreaterThan(HiAirGlassProminence.hero.borderAlpha, HiAirGlassProminence.hero.outerGlowAlpha)
        XCTAssertLessThan(HiAirGlassProminence.standard.blurRadius, 16)
    }
}
