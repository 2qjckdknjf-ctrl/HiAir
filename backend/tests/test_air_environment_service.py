import pytest

import app.services.air_environment_service as air_environment_service
import app.services.air_repository as air_repository
from app.models.risk import EnvironmentSnapshot


def _live_snapshot() -> EnvironmentSnapshot:
    return EnvironmentSnapshot(
        temperature_c=22.0,
        humidity_percent=48.0,
        aqi=55,
        pm25=11.0,
        ozone=42.0,
        source="live",
    )


def _cached_snapshot() -> EnvironmentSnapshot:
    return EnvironmentSnapshot(
        temperature_c=20.0,
        humidity_percent=52.0,
        aqi=60,
        pm25=13.0,
        ozone=45.0,
        source="live",
        # Mark as post-migration so cache-first path does not force a live refresh.
        shortwave_wm2=120.0,
        wbgt_c=18.5,
        wbgt_estimated=True,
    )


def test_resolve_serves_fresh_cache_before_live(monkeypatch) -> None:
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: pytest.fail("live must not be called when fresh cache exists"),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: _cached_snapshot(),
    )

    result = air_environment_service.resolve_environment_snapshot(41.39, 2.17)
    assert result.source == "cached"
    assert result.aqi == 60


def test_resolve_uses_live_when_cache_misses(monkeypatch) -> None:
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: _live_snapshot(),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: None,
    )

    result = air_environment_service.resolve_environment_snapshot(41.39, 2.17)
    assert result.source == "live"
    assert result.aqi == 55


def test_resolve_force_refresh_prefers_live_over_cache(monkeypatch) -> None:
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: _live_snapshot(),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: _cached_snapshot(),
    )

    result = air_environment_service.resolve_environment_snapshot(
        41.39, 2.17, force_refresh=True
    )
    assert result.source == "live"
    assert result.aqi == 55


def test_resolve_falls_back_to_cache_when_live_fails(monkeypatch) -> None:
    """When force_refresh skips cache-first, live failure may still use late cache."""
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("provider down")),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: _cached_snapshot(),
    )

    result = air_environment_service.resolve_environment_snapshot(
        41.39, 2.17, force_refresh=True
    )
    assert result.source == "cached"
    assert result.aqi == 60


def test_resolve_rejects_persisted_sample_when_fallback_disabled(monkeypatch) -> None:
    """Regression: sample/mock DB rows must not be re-labeled as cached in production."""
    from types import SimpleNamespace

    monkeypatch.setattr(
        air_environment_service,
        "settings",
        SimpleNamespace(
            environment_cache_ttl_seconds=900,
            environment_allow_sample_fallback=False,
        ),
    )
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("provider down")),
    )
    sample_row = EnvironmentSnapshot(
        temperature_c=21.0,
        humidity_percent=50.0,
        aqi=33,
        pm25=8.0,
        ozone=20.0,
        source="sample",
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: sample_row,
    )
    with pytest.raises(RuntimeError, match="sample fallback is disabled"):
        air_environment_service.resolve_environment_snapshot(41.39, 2.17)


def test_resolve_keeps_honest_sample_label_when_fallback_allowed(monkeypatch) -> None:
    from types import SimpleNamespace

    monkeypatch.setattr(
        air_environment_service,
        "settings",
        SimpleNamespace(
            environment_cache_ttl_seconds=900,
            environment_allow_sample_fallback=True,
        ),
    )
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("provider down")),
    )
    sample_row = EnvironmentSnapshot(
        temperature_c=21.0,
        humidity_percent=50.0,
        aqi=33,
        pm25=8.0,
        ozone=20.0,
        source="sample",
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: sample_row,
    )
    result = air_environment_service.resolve_environment_snapshot(41.39, 2.17)
    assert result.source == "sample"
    assert result.aqi == 33

def test_resolve_falls_back_to_sample_when_live_and_cache_unavailable(monkeypatch) -> None:
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("provider down")),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: None,
    )

    result = air_environment_service.resolve_environment_snapshot(41.39, 2.17)
    assert result.source == "sample"
    assert result.aqi >= 0


def test_resolve_sample_disabled_raises_when_unavailable(monkeypatch) -> None:
    from types import SimpleNamespace

    monkeypatch.setattr(
        air_environment_service,
        "settings",
        SimpleNamespace(
            environment_cache_ttl_seconds=900,
            environment_allow_sample_fallback=False,
        ),
    )
    monkeypatch.setattr(
        air_environment_service,
        "fetch_live_snapshot",
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("provider down")),
    )
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: None,
    )

    with pytest.raises(RuntimeError, match="sample fallback is disabled"):
        air_environment_service.resolve_environment_snapshot(41.39, 2.17)


def test_honest_cached_snapshot_fills_missing_meteo_wbgt(monkeypatch) -> None:
    import app.services.wbgt_estimate as wbgt_estimate
    from app.models.risk import EnvironmentSnapshot

    monkeypatch.setattr(wbgt_estimate, "estimate_outdoor_wbgt_c", lambda *a, **k: 27.5)

    cached = EnvironmentSnapshot(
        temperature_c=33.0,
        humidity_percent=40.0,
        aqi=50,
        pm25=8.0,
        ozone=40.0,
        source="live",
        wind_speed=2.0,
        wbgt_c=None,
        wbgt_estimated=False,
    )
    honest = air_environment_service._honest_cached_snapshot(cached)
    assert honest is not None
    assert honest.source == "cached"
    assert honest.wbgt_c == 27.5
    assert honest.wbgt_estimated is True


def test_resolve_refreshes_live_when_cache_lacks_post_migration_fields(monkeypatch) -> None:
    live = EnvironmentSnapshot(
        temperature_c=33.0,
        humidity_percent=30.0,
        aqi=46,
        pm25=5.0,
        ozone=80.0,
        source="live",
        pollen_grains_m3=2.3,
        wildfire_pm10=0.1,
        wbgt_c=26.5,
        wbgt_estimated=True,
        shortwave_wm2=700.0,
    )
    stale = EnvironmentSnapshot(
        temperature_c=32.0,
        humidity_percent=35.0,
        aqi=50,
        pm25=6.0,
        ozone=70.0,
        source="live",
    )
    monkeypatch.setattr(air_environment_service, "fetch_live_snapshot", lambda lat, lon: live)
    monkeypatch.setattr(
        air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: stale,
    )
    monkeypatch.setattr(
        air_repository,
        "save_resolved_environment_snapshot",
        lambda snapshot, lat, lon: "ok",
    )

    result = air_environment_service.resolve_environment_snapshot(41.39, 2.17)
    assert result.source == "live"
    assert result.pollen_grains_m3 == 2.3
    assert result.wbgt_c == 26.5
