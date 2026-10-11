"""WBGT meteo estimate tests."""

from app.services.wbgt_estimate import estimate_outdoor_wbgt_c, stull_wet_bulb_c


def test_stull_wet_bulb_between_air_temp_bounds() -> None:
    tw = stull_wet_bulb_c(35.0, 50.0)
    assert 20.0 < tw < 35.0


def test_estimate_outdoor_wbgt_rises_with_solar() -> None:
    shade = estimate_outdoor_wbgt_c(35.0, 45.0, wind_speed_ms=2.0, shortwave_wm2=0.0)
    sun = estimate_outdoor_wbgt_c(35.0, 45.0, wind_speed_ms=2.0, shortwave_wm2=800.0)
    assert shade is not None and sun is not None
    assert sun > shade
