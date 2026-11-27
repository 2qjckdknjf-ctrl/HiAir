from app.services import environment_service


def test_optional_aqi_keeps_zero_when_explicit() -> None:
    assert environment_service._optional_aqi(0) == 0
    assert environment_service._optional_aqi("0") == 0


def test_optional_aqi_does_not_coerce_sentinels_to_zero() -> None:
    for token in ("", "-", "n/a", "unknown", "null", None, "--"):
        assert environment_service._optional_aqi(token) is None


def test_openmeteo_aqi_zero_is_valid_reading(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_service.httpx,
        "Client",
        lambda *args, **kwargs: _FakeClient(
            {
                "current": {
                    "us_aqi": 0,
                    "pm2_5": 1.0,
                    "ozone": 2.0,
                    "pm10": 3.0,
                }
            }
        ),
    )
    result = environment_service._fetch_openmeteo_aqi(41.39, 2.17)
    assert result["aqi"] == 0
    assert result["pm25"] == 1.0


def test_live_snapshot_includes_provenance(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_service,
        "settings",
        type(
            "S",
            (),
            {
                "weather_api_provider": "openmeteo",
                "aqi_api_provider": "openmeteo",
                "weather_api_key": "",
                "aqi_api_key": "",
            },
        )(),
    )
    monkeypatch.setattr(
        environment_service,
        "_fetch_openmeteo_weather",
        lambda lat, lon: {
            "temperature_c": 22.0,
            "humidity_percent": 40.0,
            "feels_like": 22.0,
            "wind_speed": 1.0,
            "uv": 3.0,
            "shortwave_wm2": 100.0,
            "timezone": "UTC",
        },
    )
    monkeypatch.setattr(
        environment_service,
        "_fetch_openmeteo_aqi",
        lambda lat, lon: {
            "aqi": 12,
            "pm25": 5.0,
            "ozone": 20.0,
            "pm10": 10.0,
            "no2": 8.0,
            "pollen_grains_m3": None,
            "wildfire_pm10": None,
        },
    )
    monkeypatch.setattr(
        environment_service,
        "resolve_pollen_smoke",
        lambda *args, **kwargs: type(
            "R",
            (),
            {"pollen_grains_m3": None, "wildfire_pm10": None},
        )(),
    )
    snapshot = environment_service.fetch_live_snapshot(41.39, 2.17)
    assert snapshot.weather_provider == "openmeteo"
    assert snapshot.aqi_provider == "openmeteo"
    assert snapshot.received_at
    assert snapshot.data_quality == "complete"
    assert snapshot.aqi == 12


class _FakeClient:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None

    def get(self, url: str, params: dict | None = None):
        class Resp:
            def raise_for_status(self_inner) -> None:
                return None

            def json(self_inner) -> dict:
                return self._payload

        return Resp()
