"""HiAir 1.1 Forecast Truth integrity contract."""

from __future__ import annotations

import inspect

import app.api.planner as planner_api
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
from app.models.risk import EnvironmentSnapshot
from app.services import air_score


def test_day_plan_source_does_not_project_environment() -> None:
    source = inspect.getsource(air_risk_engine.build_day_plan)
    assert "_project_environment" not in source
    assert "hourly_points" in source


def test_planner_daily_source_does_not_shift_env() -> None:
    source = inspect.getsource(planner_api.daily_planner)
    assert "_shift_env" not in source
    assert "get_forecast" in source


def test_snapshot_mapper_does_not_infer_uv_pm10_wind() -> None:
    source = inspect.getsource(air_environment_service._snapshot_to_environmental)
    assert "pm25 * 1.45" not in source
    assert "temperature_c - 16" not in source
    assert "humidity_percent / 100 * 2.8" not in source


def test_air_score_does_not_hardcode_uv_wind_or_scale_pm10() -> None:
    source = inspect.getsource(air_score.to_air_environment)
    assert "uv=4.0" not in source
    assert "wind_speed=2.0" not in source
    assert "* 1.4" not in source


def test_missing_optional_metrics_stay_none() -> None:
    snapshot = EnvironmentSnapshot(
        temperature_c=22.0,
        humidity_percent=40.0,
        aqi=40,
        pm25=10.0,
        ozone=30.0,
        source="live",
    )
    mapped = air_environment_service._snapshot_to_environmental(snapshot, 41.39, 2.17, "UTC")
    assert mapped.pm10 is None
    assert mapped.uv is None
    assert mapped.wind_speed is None
    env = air_score.to_air_environment(snapshot, 41.39, 2.17)
    assert env.pm10 is None
    assert env.uv is None
    assert env.wind_speed is None


def test_direct_provider_metrics_are_passed_through() -> None:
    snapshot = EnvironmentSnapshot(
        temperature_c=22.0,
        humidity_percent=40.0,
        aqi=40,
        pm25=10.0,
        ozone=30.0,
        source="live",
        pm10=18.0,
        uv=6.5,
        wind_speed=3.2,
        feels_like=23.0,
        timezone="Europe/Madrid",
    )
    mapped = air_environment_service._snapshot_to_environmental(snapshot, 41.39, 2.17, "UTC")
    assert mapped.pm10 == 18.0
    assert mapped.uv == 6.5
    assert mapped.wind_speed == 3.2
    assert mapped.feels_like == 23.0
    assert mapped.timezone == "Europe/Madrid"
