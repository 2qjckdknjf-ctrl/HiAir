import XCTest
@testable import HiAir

final class DailyPlannerSurfaceStateTests: XCTestCase {
    func testForecastBannerHiddenWhenDataPresent() {
        let surface = PlannerForecastSurface.loaded(hours: 12)
        XCTAssertNil(surface.bannerMessage)
        XCTAssertTrue(surface.hasDisplayableData)
    }

    func testForecastFailureShowsBannerOnlyWithoutData() {
        let message = HiAirL10n.t("planner.empty.unavailable.body", lang: "en")
        let surface = PlannerForecastSurface.failed(message: message)
        XCTAssertEqual(surface.bannerMessage, message)
        XCTAssertFalse(surface.hasDisplayableData)
    }

    func testActivityFailureUsesSoftMessageWhenForecastLoaded() async {
        await MainActor.run {
            let model = DailyPlannerViewModel()
            model.hourlyItems = [AirHourlyRiskPoint(hour: "2026-08-08T10:00:00Z", overallRisk: "low")]
            let soft = model.activityFailureMessage(language: "en", forecastLoaded: model.hasForecastData)
            XCTAssertEqual(soft, HiAirL10n.t("planner.activity.forecast_unavailable", lang: "en"))
            XCTAssertFalse(soft.localizedCaseInsensitiveContains("connection"))
        }
    }

    func testActivityFailureUsesConnectionMessageWhenForecastEmpty() async {
        await MainActor.run {
            let model = DailyPlannerViewModel()
            let hard = model.activityFailureMessage(language: "en", forecastLoaded: false)
            XCTAssertEqual(hard, HiAirL10n.t("planner.empty.unavailable.body", lang: "en"))
        }
    }

    func testActivityInlineSuppressedWhenWindowsLoaded() {
        let surface = PlannerActivitySurface.loaded(windowCount: 2)
        XCTAssertNil(surface.inlineMessage)
        XCTAssertTrue(surface.hasDisplayableData)
    }

    func testSuccessPlusStaleActivityErrorDoesNotPolluteForecastBanner() {
        let forecast = PlannerForecastSurface.loaded(hours: 24)
        let activity = PlannerActivitySurface.failed(
            message: HiAirL10n.t("planner.activity.forecast_unavailable", lang: "en")
        )
        XCTAssertNil(forecast.bannerMessage)
        XCTAssertNotNil(activity.inlineMessage)
        XCTAssertTrue(forecast.hasDisplayableData)
        XCTAssertFalse(activity.hasDisplayableData)
        XCTAssertFalse(
            (activity.inlineMessage ?? "").contains(
                HiAirL10n.t("planner.empty.unavailable.body", lang: "en")
            )
        )
    }
}
