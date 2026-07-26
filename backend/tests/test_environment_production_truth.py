"""Production-truth tests for environment snapshot API (no synthetic sample in prod)."""

from __future__ import annotations

from types import SimpleNamespace

from fastapi.testclient import TestClient

import app.api.environment as environment_api
import app.services.air_environment_service as air_environment_service
from app.main import app


def test_production_rejects_sample_and_mock_sources(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_api,
        "settings",
        SimpleNamespace(app_env="production", environment_allow_sample_fallback=False),
    )
    client = TestClient(app)
    for source in ("sample", "mock"):
        response = client.get(
            "/api/environment/snapshot",
            params={"lat": 41.39, "lon": 2.17, "source": source},
        )
        assert response.status_code == 403
        assert "sample" in response.json()["detail"].lower()


def test_production_cached_unavailable_returns_503_not_sample(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_api,
        "settings",
        SimpleNamespace(app_env="production", environment_allow_sample_fallback=False),
    )
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
        air_environment_service.air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: None,
    )
    client = TestClient(app)
    response = client.get(
        "/api/environment/snapshot",
        params={"lat": 41.39, "lon": 2.17, "source": "cached"},
    )
    assert response.status_code == 503
    body = response.json()
    assert body.get("source") not in ("sample", "mock")


def test_development_allows_sample_when_fallback_enabled(monkeypatch) -> None:
    monkeypatch.setattr(
        environment_api,
        "settings",
        SimpleNamespace(app_env="development", environment_allow_sample_fallback=True),
    )
    client = TestClient(app)
    response = client.get(
        "/api/environment/snapshot",
        params={"lat": 41.39, "lon": 2.17, "source": "sample"},
    )
    assert response.status_code == 200
    assert response.json()["source"] == "sample"


def test_resolve_never_returns_sample_when_disabled(monkeypatch) -> None:
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
        lambda lat, lon: (_ for _ in ()).throw(RuntimeError("down")),
    )
    monkeypatch.setattr(
        air_environment_service.air_repository,
        "get_latest_environment_snapshot",
        lambda lat, lon, max_age_seconds: None,
    )
    try:
        air_environment_service.resolve_environment_snapshot(1.0, 2.0)
        raised = False
    except RuntimeError as exc:
        raised = True
        assert "sample fallback is disabled" in str(exc)
    assert raised
