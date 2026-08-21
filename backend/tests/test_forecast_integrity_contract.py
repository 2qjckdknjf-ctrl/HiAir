"""HiAir 1.1 Forecast Truth integrity contract.

Target-behavior tests are xfailed until implementation commits land.
Inventory tests below document current production helpers so the gap is explicit.
"""

from __future__ import annotations

import inspect

import pytest

import app.api.planner as planner_api
import app.services.air_environment_service as air_environment_service
import app.services.air_risk_engine as air_risk_engine
from app.services import air_score


def test_inventory_project_environment_is_currently_used_by_day_plan() -> None:
    source = inspect.getsource(air_risk_engine.build_day_plan)
    assert "_project_environment" in source


def test_inventory_shift_env_exists_on_planner_daily() -> None:
    source = inspect.getsource(planner_api.daily_planner)
    assert "_shift_env" in source


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


@pytest.mark.xfail(strict=True, reason="HiAir 1.1: remove production synthetic forecast")
def test_day_plan_source_does_not_project_environment() -> None:
    source = inspect.getsource(air_risk_engine.build_day_plan)
    assert "_project_environment" not in source


@pytest.mark.xfail(strict=True, reason="HiAir 1.1: remove production synthetic forecast")
def test_planner_daily_source_does_not_shift_env() -> None:
    source = inspect.getsource(planner_api.daily_planner)
    assert "_shift_env" not in source


@pytest.mark.xfail(strict=True, reason="HiAir 1.1: no heuristic UV/PM10/wind")
def test_snapshot_mapper_does_not_infer_uv_pm10_wind() -> None:
    source = inspect.getsource(air_environment_service._snapshot_to_environmental)
    assert "pm25 * 1.45" not in source
    assert "temperature_c - 16" not in source


@pytest.mark.xfail(strict=True, reason="HiAir 1.1: no heuristic UV/PM10/wind")
def test_air_score_does_not_hardcode_uv_wind_or_scale_pm10() -> None:
    source = inspect.getsource(air_score.to_air_environment)
    assert "uv=4.0" not in source
    assert "wind_speed=2.0" not in source
    assert "* 1.4" not in source
