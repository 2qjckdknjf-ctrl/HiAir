from types import SimpleNamespace

from fastapi.testclient import TestClient

import app.api.environment as environment_api
import app.api.subscriptions as subscriptions_api
import app.api.deps as deps
import app.main as main_module
from app.main import app


def test_environment_live_requires_auth_header(monkeypatch) -> None:
    monkeypatch.setattr(environment_api, "fetch_live_snapshot", lambda lat, lon: None)
    client = TestClient(app)
    response = client.get("/api/environment/snapshot", params={"lat": 41.39, "lon": 2.17, "source": "live"})
    assert response.status_code == 401


def test_manual_subscription_activation_blocked_in_protected_env(monkeypatch) -> None:
    monkeypatch.setattr(deps, "decode_access_token", lambda token: "user-1")
    monkeypatch.setattr(deps.user_repository, "user_exists", lambda user_id: True)
    monkeypatch.setattr(
        subscriptions_api,
        "settings",
        SimpleNamespace(app_env="production", subscription_provider="stub"),
    )
    client = TestClient(app)
    response = client.post(
        "/api/subscriptions/activate",
        json={"plan_id": "basic_monthly", "use_trial": False},
        headers={"Authorization": "Bearer token"},
    )
    assert response.status_code == 403
    detail = response.json()["detail"]
    assert "disabled in protected environments" in detail or "Manual activation is disabled" in detail


def test_create_app_hides_docs_in_protected_env(monkeypatch) -> None:
    monkeypatch.setattr(
        main_module,
        "settings",
        SimpleNamespace(
            app_env="production",
            jwt_secret="test-secret",
            allow_legacy_user_header_auth=False,
            allow_insecure_local_dev=False,
        ),
    )
    app_instance = main_module.create_app()
    assert app_instance.docs_url is None
    assert app_instance.redoc_url is None
    assert app_instance.openapi_url is None
