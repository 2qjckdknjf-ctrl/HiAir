from app.models.air import EnvironmentalInput, ProfileType, RiskLevel, UserProfileContext
from app.services.air_risk_engine import build_day_plan, evaluate_risk


def build_profile(profile_type: ProfileType) -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=profile_type,
        age_group="adult",
        heat_sensitivity_level=3,
        respiratory_sensitivity_level=3,
        activity_level="moderate",
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def build_environment() -> EnvironmentalInput:
    return EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=35.0,
        feels_like=39.0,
        humidity=70.0,
        aqi=142,
        pm25=42.0,
        pm10=58.0,
        ozone=105.0,
        uv=8.4,
        wind_speed=1.2,
        source="test",
        timestamp="2026-04-07T10:00:00+00:00",
        timezone="UTC",
    )


def test_asthma_profile_gets_high_risk() -> None:
    result = evaluate_risk(build_profile(ProfileType.ASTHMA_SENSITIVE), build_environment())
    assert result.overallRisk in (RiskLevel.HIGH, RiskLevel.VERY_HIGH)
    assert "asthma_caution" in result.recommendationFlags
    assert "poor_air_quality" in result.reasonCodes or "very_poor_air_quality" in result.reasonCodes


def test_low_conditions_stay_low_for_default_profile() -> None:
    profile = build_profile(ProfileType.ADULT_DEFAULT)
    environment = EnvironmentalInput(
        lat=41.39,
        lon=2.17,
        temperature=23.0,
        feels_like=23.5,
        humidity=45.0,
        aqi=35,
        pm25=8.0,
        pm10=12.0,
        ozone=40.0,
        uv=2.0,
        wind_speed=2.4,
        source="test",
        timestamp="2026-04-07T05:00:00+00:00",
        timezone="UTC",
    )
    result = evaluate_risk(profile, environment)
    assert result.overallRisk == RiskLevel.LOW
    assert "avoid_outdoor_now" not in result.recommendationFlags


def test_day_plan_uses_provided_hourly_points_not_synthetic() -> None:
    profile = build_profile(ProfileType.RUNNER)
    base = build_environment()
    hourly = []
    for offset in range(24):
        hourly.append(
            EnvironmentalInput(
                lat=base.lat,
                lon=base.lon,
                temperature=22.0 if offset < 12 else 36.0,
                feels_like=22.5 if offset < 12 else 39.0,
                humidity=45.0,
                aqi=30 if offset < 12 else 150,
                pm25=8.0 if offset < 12 else 42.0,
                pm10=12.0 if offset < 12 else 58.0,
                ozone=40.0 if offset < 12 else 105.0,
                uv=2.0 if offset < 12 else 8.4,
                wind_speed=2.4,
                source="forecast",
                timestamp=f"2026-07-15T{offset:02d}:00:00+02:00",
                timezone="Europe/Madrid",
            )
        )
    plan = build_day_plan(profile, base, hourly_points=hourly)
    assert len(plan.hourlyRisk) == 24
    assert plan.forecastAvailable is True
    assert plan.hourlyRisk[0].hour.endswith("+02:00")
    assert plan.hourlyRisk[0].overallRisk == RiskLevel.LOW
    assert plan.hourlyRisk[18].overallRisk in (RiskLevel.HIGH, RiskLevel.VERY_HIGH)
    assert plan.safeWindows
    assert all(window.start.endswith("+02:00") for window in plan.safeWindows)


def test_day_plan_unavailable_without_hourly_points() -> None:
    plan = build_day_plan(build_profile(ProfileType.ADULT_DEFAULT), build_environment(), hourly_points=[])
    assert plan.hourlyRisk == []
    assert plan.safeWindows == []
    assert plan.forecastAvailable is False
