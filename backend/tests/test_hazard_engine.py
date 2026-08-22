"""HiAir 1.3 multi-hazard engine tests."""

from app.models.air import EnvironmentalInput, ProfileType, UserProfileContext
from app.models.hazard import HazardLevel, HazardType
from app.services.hazard_engine import (
    assess_multi_hazard,
    score_air,
    score_dust,
    score_heat,
    score_pollen,
    score_smoke,
    score_uv,
)


def _profile(profile_type: ProfileType = ProfileType.ADULT_DEFAULT) -> UserProfileContext:
    return UserProfileContext(
        profile_id="profile-1",
        user_id="user-1",
        profile_type=profile_type,
        heat_sensitivity_level=3,
        respiratory_sensitivity_level=3,
        timezone="UTC",
        home_lat=41.39,
        home_lon=2.17,
    )


def _environment(**overrides: object) -> EnvironmentalInput:
    base = {
        "lat": 41.39,
        "lon": 2.17,
        "temperature": 26.0,
        "feels_like": 28.0,
        "humidity": 55.0,
        "aqi": 65,
        "pm25": 12.0,
        "pm10": 18.0,
        "ozone": 60.0,
        "uv": 5.0,
        "wind_speed": 2.1,
        "source": "openmeteo",
        "timestamp": "2026-08-21T10:00:00Z",
        "timezone": "UTC",
    }
    base.update(overrides)
    return EnvironmentalInput(**base)


def test_score_heat_reflects_extreme_feels_like() -> None:
    result = score_heat(_environment(feels_like=41.0, humidity=80.0), _profile())
    assert result.available is True
    assert result.level == HazardLevel.VERY_HIGH
    assert "extreme_heat_index" in result.reasonCodes


def test_score_air_unavailable_without_air_metrics() -> None:
    result = score_air(
        _environment(aqi=None, pm25=None, pm10=None, ozone=None),
        _profile(),
    )
    assert result.available is False
    assert result.level == HazardLevel.UNAVAILABLE
    assert result.unavailableReason == "air_metrics_unavailable"


def test_score_air_includes_no2_when_present() -> None:
    result = score_air(_environment(no2=95.0), _profile())
    assert result.available is True
    assert "no2_elevated" in result.reasonCodes


def test_score_air_high_for_poor_aqi_and_asthma_profile() -> None:
    result = score_air(
        _environment(aqi=150, pm25=40.0),
        _profile(ProfileType.ASTHMA_SENSITIVE),
    )
    assert result.available is True
    assert result.level in (HazardLevel.HIGH, HazardLevel.VERY_HIGH)
    assert "profile_respiratory_sensitivity" in result.reasonCodes


def test_score_uv_unavailable_when_missing() -> None:
    result = score_uv(_environment(uv=None), _profile())
    assert result.available is False
    assert result.unavailableReason == "uv_unavailable"


def test_score_uv_high_for_peak_index() -> None:
    result = score_uv(_environment(uv=9.0), _profile())
    assert result.available is True
    assert result.level == HazardLevel.VERY_HIGH
    assert "uv_very_high" in result.reasonCodes


def test_pollen_and_smoke_unavailable_without_provider() -> None:
    env = _environment()
    profile = _profile()
    for scorer in (score_pollen, score_smoke):
        result = scorer(env, profile)
        assert result.available is False
        assert result.level == HazardLevel.UNAVAILABLE
        assert result.unavailableReason == "provider_not_configured"


def test_score_dust_from_pm10() -> None:
    result = score_dust(_environment(pm10=85.0), _profile())
    assert result.available is True
    assert result.level == HazardLevel.HIGH
    assert "pm10_coarse_particulate" in result.reasonCodes


def test_score_dust_unavailable_without_pm10() -> None:
    result = score_dust(_environment(pm10=None), _profile())
    assert result.available is False
    assert result.unavailableReason == "pm10_unavailable"


def test_assess_multi_hazard_returns_all_six_modules() -> None:
    assessment = assess_multi_hazard(_profile(), _environment())
    hazards = {item.hazard for item in assessment.hazards}
    assert hazards == {
        HazardType.HEAT,
        HazardType.AIR,
        HazardType.UV,
        HazardType.POLLEN,
        HazardType.SMOKE,
        HazardType.DUST,
    }
    assert assessment.availableCount == 4
    assert assessment.overallLevel in (HazardLevel.MODERATE, HazardLevel.HIGH)


def test_assess_multi_hazard_aggregates_available_only() -> None:
    assessment = assess_multi_hazard(
        _profile(),
        _environment(feels_like=22.0, aqi=None, pm25=None, pm10=None, ozone=None, uv=None),
    )
    available = [item for item in assessment.hazards if item.available]
    assert len(available) == 1
    assert available[0].hazard == HazardType.HEAT
    assert assessment.overallLevel == HazardLevel.LOW
    assert assessment.overallScore == 20
