"""Pollen/smoke secondary providers fill nulls only — never overwrite."""

from app.services.pollen_smoke import PollenSmokeReading, merge_pollen_smoke_readings
from app.services.pollen_smoke.providers import AmbeePollenSmokeProvider


def test_merge_fills_nulls_only() -> None:
    merged = merge_pollen_smoke_readings(
        PollenSmokeReading(pollen_grains_m3=5.0, wildfire_pm10=None, pollen_source="cams"),
        PollenSmokeReading(
            pollen_grains_m3=99.0,
            wildfire_pm10=8.0,
            pollen_source="ambee",
            smoke_source="s",
        ),
    )
    assert merged.pollen_grains_m3 == 5.0
    assert merged.wildfire_pm10 == 8.0
    assert merged.pollen_source == "cams"
    assert merged.smoke_source == "s"


def test_ambee_without_key_returns_empty(monkeypatch) -> None:
    monkeypatch.setattr(
        "app.services.pollen_smoke.providers.settings",
        type("S", (), {"ambee_api_key": ""})(),
    )
    reading = AmbeePollenSmokeProvider().fetch(40.7, -74.0)
    assert reading.pollen_grains_m3 is None
    assert reading.wildfire_pm10 is None
