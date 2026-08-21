"""Honesty tests for live environment adapters — no fake zeros for missing metrics."""

from __future__ import annotations

import pytest

from app.services import environment_service


def test_openmeteo_aqi_keeps_missing_metrics_null(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_service.httpx,
        "Client",
        lambda *args, **kwargs: _FakeClient(
            {
                "current": {
                    "us_aqi": 42,
                    "pm2_5": None,
                    "ozone": 30,
                    "pm10": None,
                }
            }
        ),
    )
    result = environment_service._fetch_openmeteo_aqi(41.39, 2.17)
    assert result["aqi"] == 42
    assert result["pm25"] is None
    assert result["ozone"] == 30.0
    assert result["pm10"] is None


def test_openmeteo_aqi_fails_when_all_air_metrics_missing(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_service.httpx,
        "Client",
        lambda *args, **kwargs: _FakeClient({"current": {}}),
    )
    with pytest.raises(ValueError, match="no air metrics"):
        environment_service._fetch_openmeteo_aqi(41.39, 2.17)


def test_waqi_keeps_missing_iaqi_null(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_service,
        "settings",
        type("S", (), {"aqi_api_key": "token"})(),
    )
    monkeypatch.setattr(
        environment_service.httpx,
        "Client",
        lambda *args, **kwargs: _FakeClient(
            {
                "data": {
                    "aqi": 55,
                    "iaqi": {},
                }
            }
        ),
    )
    result = environment_service._fetch_waqi(41.39, 2.17)
    assert result["aqi"] == 55
    assert result["pm25"] is None
    assert result["ozone"] is None


def test_forecast_mapping_does_not_default_missing_humidity_to_zero() -> None:
    from app.models.forecast import (
        EnvironmentalDataKind,
        EnvironmentalForecastPoint,
        ForecastQuality,
        MetricProvenance,
    )
    from app.services.forecast.mapping import forecast_point_to_environmental

    point = EnvironmentalForecastPoint(
        timestamp="2026-07-15T08:00:00+02:00",
        timezone="Europe/Madrid",
        lat=41.39,
        lon=2.17,
        temperature_c=24.0,
        apparent_temperature_c=None,
        relative_humidity_pct=None,
        dew_point_c=None,
        wind_speed_mps=None,
        wind_gust_mps=None,
        uv_index=None,
        aqi=40,
        pm25_ugm3=8.0,
        pm10_ugm3=None,
        ozone_ugm3=30.0,
        provenance=MetricProvenance(
            provider="openmeteo",
            product="test",
            observed_at="2026-07-15T08:00:00+02:00",
            fetched_at="2026-07-15T08:00:00+02:00",
            kind=EnvironmentalDataKind.FORECAST,
        ),
        missing_metrics=["relative_humidity_pct"],
        quality=ForecastQuality.PARTIAL,
    )
    mapped = forecast_point_to_environmental(point)
    assert mapped is not None
    assert mapped.humidity is None


class _FakeClient:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def get(self, *args, **kwargs):
        return _FakeResponse(self._payload)


class _FakeResponse:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self._payload
