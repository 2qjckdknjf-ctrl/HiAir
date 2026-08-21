"""HiAir 1.1 Forecast Truth integrity contract."""

from __future__ import annotations

import inspect

import app.api.planner as planner_api
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
from app.services import air_score


def test_day_plan_source_does_not_project_environment() -> None:
    source = inspect.getsource(air_risk_engine.build_day_plan)
    assert "_project_environment" not in source
    assert "hourly_points" in source


def test_planner_daily_source_does_not_shift_env() -> None:
    source = inspect.getsource(planner_api.daily_planner)
    assert "_shift_env" not in source
    assert "get_forecast" in source


def test_inventory_heuristic_pm10_uv_wind_in_snapshot_mapper() -> None:
    source = inspect.getsource(air_environment_service._snapshot_to_environmental)
    assert "pm25 * 1.45" in source
    assert "temperature_c - 16" in source
    assert "humidity_percent / 100" in source


def test_inventory_air_score_hardcodes_uv_and_wind() -> None:
    source = inspect.getsource(air_score.to_air_environment)
    assert "uv=4.0" in source
    assert "wind_speed=2.0" in source
    assert "* 1.4" in source
