import base64
import hashlib
import hmac
import json
import os
import sys
from pathlib import Path
from uuid import UUID
from uuid import uuid4

# Configure smoke auth mode before settings import.
_db_url = os.getenv("DATABASE_URL", "")
_is_supabase_remote_db = "supabase.com" in _db_url or "pooler.supabase.com" in _db_url
_has_supabase_smoke_config = bool(os.getenv("SUPABASE_URL")) and bool(
    os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
)
_use_supabase_smoke_auth = _is_supabase_remote_db and _has_supabase_smoke_config

if _use_supabase_smoke_auth:
    os.environ["HIAIR_AUTH_PROVIDER"] = "supabase"
    os.environ["HIAIR_AUTH_LEGACY_ENABLED"] = "false"
elif os.getenv("HIAIR_SMOKE_LEGACY_AUTH", "").lower() == "true" or "localhost" in _db_url:
    os.environ["HIAIR_AUTH_PROVIDER"] = "legacy"
    os.environ["SUPABASE_URL"] = ""
    os.environ["HIAIR_AUTH_LEGACY_ENABLED"] = "false"

import httpx
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import app
from app.core.settings import _is_protected_env, settings
from app.services.db import get_connection


def _stub_ios_signed_transaction(product_id: str) -> str:
    payload = {
        "productId": product_id,
        "transactionId": f"smoke_{uuid4().hex[:12]}",
        "originalTransactionId": f"smoke_{uuid4().hex[:12]}",
        "status": "active",
    }
    header = base64.urlsafe_b64encode(b'{"alg":"none"}').decode().rstrip("=")
    body = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{header}.{body}.stub"


def _ensure_smoke_premium(client: TestClient, auth_headers: dict[str, str]) -> None:
    """Grant premium for smoke: stub activate locally, store verify stub on staging/production."""
    use_activate = (
        settings.subscription_provider == "stub"
        and not _is_protected_env(settings.app_env)
    )
    if use_activate:
        activate = client.post(
            "/api/subscriptions/activate",
            headers=auth_headers,
            json={"plan_id": "basic_monthly", "use_trial": True},
        )
        if activate.status_code == 200:
            return

    verify = client.post(
        "/api/subscriptions/ios/verify",
        headers=auth_headers,
        json={
            "product_id": "com.hiair.premium.monthly",
            "signed_transaction": _stub_ios_signed_transaction("com.hiair.premium.monthly"),
        },
    )
    assert verify.status_code == 200, (
        f"Could not grant smoke premium (provider={settings.subscription_provider}, "
        f"app_env={settings.app_env}): {verify.text}"
    )


def _supabase_service_role_key() -> str:
    return (
        settings.supabase_service_role_key.strip()
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    )


def _supabase_anon_key() -> str:
    return settings.supabase_anon_key.strip() or os.getenv("SUPABASE_ANON_KEY", "").strip()


def supabase_smoke_create_session(email: str, password: str) -> tuple[str, str]:
    base = settings.supabase_url.rstrip("/")
    service_key = _supabase_service_role_key()
    anon_key = _supabase_anon_key()
    if not base or not service_key or not anon_key:
        raise RuntimeError("Supabase smoke auth requires SUPABASE_URL, service role, and anon keys")

    with httpx.Client(timeout=30.0) as http:
        create = http.post(
            f"{base}/auth/v1/admin/users",
            headers={
                "apikey": service_key,
                "Authorization": f"Bearer {service_key}",
                "Content-Type": "application/json",
            },
            json={"email": email, "password": password, "email_confirm": True},
        )
        if create.status_code not in (200, 201):
            if create.status_code != 422 or "already" not in create.text.lower():
                create.raise_for_status()
        token_resp = http.post(
            f"{base}/auth/v1/token?grant_type=password",
            headers={
                "apikey": anon_key,
                "Authorization": f"Bearer {anon_key}",
                "Content-Type": "application/json",
            },
            json={"email": email, "password": password},
        )
        token_resp.raise_for_status()
        payload = token_resp.json()
        user_id = str(payload["user"]["id"])
        access_token = str(payload["access_token"])
    return user_id, access_token


def assert_no_residual_personal_data(user_id: str, profile_ids: list[str]) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            checks = [
                ("users by id", "SELECT COUNT(*) AS total FROM users WHERE id = %s", (user_id,)),
                ("profiles by user_id", "SELECT COUNT(*) AS total FROM profiles WHERE user_id = %s", (user_id,)),
                ("user_settings by user_id", "SELECT COUNT(*) AS total FROM user_settings WHERE user_id = %s", (user_id,)),
                ("user_subscriptions by user_id", "SELECT COUNT(*) AS total FROM user_subscriptions WHERE user_id = %s", (user_id,)),
                ("push_device_tokens by user_id", "SELECT COUNT(*) AS total FROM push_device_tokens WHERE user_id = %s", (user_id,)),
                (
                    "notification_delivery_attempts by user_id",
                    "SELECT COUNT(*) AS total FROM notification_delivery_attempts WHERE user_id = %s",
                    (user_id,),
                ),
                (
                    "symptom_logs by profile_id",
                    "SELECT COUNT(*) AS total FROM symptom_logs WHERE profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "risk_scores by profile_id",
                    "SELECT COUNT(*) AS total FROM risk_scores WHERE profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "notification_events by profile_id",
                    "SELECT COUNT(*) AS total FROM notification_events WHERE profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "risk_assessments by profile_id",
                    "SELECT COUNT(*) AS total FROM risk_assessments WHERE user_profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "alert_events by profile_id",
                    "SELECT COUNT(*) AS total FROM alert_events WHERE user_profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "ai_explanation_events by profile_id",
                    "SELECT COUNT(*) AS total FROM ai_explanation_events WHERE user_profile_id::text = ANY(%s)",
                    (profile_ids,),
                ),
                (
                    "ai_recommendations by profile_id",
                    """
                    SELECT COUNT(*) AS total
                    FROM ai_recommendations r
                    JOIN risk_assessments ra ON ra.id = r.risk_assessment_id
                    WHERE ra.user_profile_id::text = ANY(%s)
                    """,
                    (profile_ids,),
                ),
            ]
            for name, query, params in checks:
                cur.execute(query, params)
                total = int(cur.fetchone()["total"])
                assert total == 0, f"Residual personal data remains for check '{name}': {total}"


def run() -> None:
    client = TestClient(app)
    email = f"smoke-{uuid4().hex[:10]}@hiair.app"
    password = "StrongPass123!"

    if _use_supabase_smoke_auth:
        smoke_user_id, access_token = supabase_smoke_create_session(email, password)
    else:
        signup = client.post("/api/auth/signup", json={"email": email, "password": password})
        assert signup.status_code == 200, signup.text
        smoke_user_id = signup.json()["user_id"]
        access_token = signup.json()["access_token"]

        login = client.post("/api/auth/login", json={"email": email, "password": password})
        assert login.status_code == 200, login.text
        assert "access_token" in login.json()

    auth_headers = {"Authorization": f"Bearer {access_token}"}
    ops_headers = (
        {"X-Admin-Token": settings.notification_admin_token}
        if settings.notification_admin_token
        else {}
    )

    profile = client.post(
        "/api/profiles",
        headers=auth_headers,
        json={
            "persona_type": "asthma",
            "sensitivity_level": "high",
            "home_lat": 41.39,
            "home_lon": 2.17,
        },
    )
    assert profile.status_code == 200, profile.text
    profile_id = profile.json()["id"]
    profile_ids = [profile_id]
    UUID(profile_id)

    symptom = client.post(
        "/api/symptoms/log",
        headers=auth_headers,
        json={
            "profile_id": profile_id,
            "symptom": {"cough": True, "wheeze": True, "fatigue": True, "sleep_quality": 2},
        },
    )
    assert symptom.status_code == 200, symptom.text

    env = client.get(
        "/api/environment/snapshot",
        params={"lat": 41.39, "lon": 2.17, "source": "mock"},
    )
    assert env.status_code == 200, env.text

    risk = client.post(
        "/api/risk/estimate",
        headers=auth_headers,
        json={
            "persona": "asthma",
            "symptoms": {"cough": True, "wheeze": True, "fatigue": True, "sleep_quality": 2},
            "environment": env.json(),
            "profile_id": profile_id,
        },
    )
    assert risk.status_code == 200, risk.text

    history = client.get(
        "/api/risk/history",
        headers=auth_headers,
        params={"profile_id": profile_id, "limit": 5},
    )
    assert history.status_code == 200, history.text
    assert len(history.json()) >= 1
    thresholds = client.get("/api/risk/thresholds")
    assert thresholds.status_code == 200, thresholds.text

    _ensure_smoke_premium(client, auth_headers)

    daily = client.get(
        "/api/recommendations/daily",
        headers=auth_headers,
        params={"profile_id": profile_id},
    )
    assert daily.status_code == 200, daily.text
    assert "actions" in daily.json()

    webhook_payload = {
        "id": f"evt_{uuid4().hex}",
        "type": "subscription.renewed",
        "data": {
            "user_id": smoke_user_id,
            "provider_subscription_id": f"stub_{uuid4().hex}",
            "plan_id": "basic_monthly",
            "status": "active",
        },
    }
    webhook_headers = {"Content-Type": "application/json"}
    webhook_body = json.dumps(webhook_payload, separators=(",", ":"), sort_keys=True)
    if settings.subscription_webhook_secret:
        signature = hmac.new(
            settings.subscription_webhook_secret.encode("utf-8"),
            webhook_body.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        webhook_headers["X-Webhook-Signature"] = signature

    webhook_1 = client.post(
        "/api/subscriptions/webhook/stub",
        data=webhook_body,
        headers=webhook_headers,
    )
    assert webhook_1.status_code == 200, webhook_1.text
    assert webhook_1.json()["duplicate"] is False
    webhook_2 = client.post(
        "/api/subscriptions/webhook/stub",
        data=webhook_body,
        headers=webhook_headers,
    )
    assert webhook_2.status_code == 200, webhook_2.text
    assert webhook_2.json()["duplicate"] is True

    settings_get = client.get("/api/settings", headers=auth_headers)
    assert settings_get.status_code == 200, settings_get.text
    settings_put = client.put(
        "/api/settings",
        headers=auth_headers,
        json={
            "push_alerts_enabled": True,
            "alert_threshold": "high",
            "default_persona": "asthma",
            "quiet_hours_start": 22,
            "quiet_hours_end": 7,
            "profile_based_alerting": True,
            "preferred_language": "en",
        },
    )
    assert settings_put.status_code == 200, settings_put.text

    briefings_get = client.get("/api/briefings/schedule", headers=auth_headers)
    assert briefings_get.status_code == 200, briefings_get.text
    briefings_put = client.put(
        "/api/briefings/schedule",
        headers=auth_headers,
        json={"local_time": "07:30", "enabled": True},
    )
    assert briefings_put.status_code == 200, briefings_put.text

    token_register = client.post(
        "/api/notifications/device-token",
        headers=auth_headers,
        json={
            "platform": "ios",
            "device_token": f"token-{uuid4().hex[:16]}",
            "profile_id": profile_id,
        },
    )
    assert token_register.status_code == 200, token_register.text

    dispatch = client.post(
        "/api/notifications/dispatch",
        headers=auth_headers,
        json={
            "risk_level": "high",
            "message": "High risk now. Limit outdoor activity.",
            "profile_id": profile_id,
        },
    )
    assert dispatch.status_code == 200, dispatch.text
    assert dispatch.json()["dispatched_to_tokens"] >= 1
    assert isinstance(dispatch.json()["provider_results"], dict)

    provider_health = client.get("/api/notifications/provider-health", headers=ops_headers)
    assert provider_health.status_code == 200, provider_health.text
    secret_store_health = client.get("/api/notifications/secret-store-health", headers=ops_headers)
    assert secret_store_health.status_code == 200, secret_store_health.text

    credentials_health = client.get("/api/notifications/credentials-health", headers=ops_headers)
    assert credentials_health.status_code == 200, credentials_health.text

    attempts = client.get(
        "/api/notifications/delivery-attempts",
        headers=auth_headers,
        params={"limit": 20},
    )
    assert attempts.status_code == 200, attempts.text
    assert len(attempts.json()) >= 1

    overview = client.get(
        "/api/dashboard/overview",
        headers=auth_headers,
        params={"profile_id": profile_id, "persona": "asthma", "lat": 41.39, "lon": 2.17},
    )
    assert overview.status_code == 200, overview.text
    assert overview.json()["risk_level"] in ("low", "moderate", "high", "very_high")

    planner = client.get(
        "/api/planner/daily",
        headers=auth_headers,
        params={"persona": "asthma", "lat": 41.39, "lon": 2.17, "hours": 12},
    )
    assert planner.status_code == 200, planner.text
    assert len(planner.json()["hourly"]) == 12

    personal_patterns = client.get(
        "/api/insights/personal-patterns",
        headers=auth_headers,
        params={"profile_id": profile_id, "window_days": 30, "language": "en"},
    )
    assert personal_patterns.status_code == 200, personal_patterns.text
    assert "items" in personal_patterns.json()

    historical_validation = client.get("/api/validation/risk/historical")
    assert historical_validation.status_code == 200, historical_validation.text
    assert historical_validation.json()["passed"] is True

    current_risk = client.get(
        "/api/air/current-risk",
        headers=auth_headers,
        params={"profileId": profile_id},
    )
    assert current_risk.status_code == 200, current_risk.text
    current_risk_body = current_risk.json()
    assert current_risk_body["profileId"] == profile_id
    assert current_risk_body.get("explanation")
    assert current_risk_body.get("explanationSource") in ("llm", "template_fallback")

    ai_summary = client.get(
        "/api/observability/ai-summary",
        headers=ops_headers,
        params={"hours": 24},
    )
    assert ai_summary.status_code == 200, ai_summary.text
    ai_summary_body = ai_summary.json()
    assert "total" in ai_summary_body
    assert "llm_success_count" in ai_summary_body
    assert "provider_configured" in ai_summary_body
    if settings.openai_api_key.strip():
        assert current_risk_body.get("explanationSource") == "llm", current_risk.text
        assert int(ai_summary_body.get("llm_success_count") or 0) >= 1, ai_summary.text

    ai_summary_detailed = client.get(
        "/api/observability/ai-summary-detailed",
        headers=ops_headers,
        params={"hours": 24},
    )
    assert ai_summary_detailed.status_code == 200, ai_summary_detailed.text
    assert "summary" in ai_summary_detailed.json()
    assert "breakdown" in ai_summary_detailed.json()

    metrics = client.get("/api/observability/metrics", headers=ops_headers)
    assert metrics.status_code == 200, metrics.text
    assert "total_requests" in metrics.json()

    if _use_supabase_smoke_auth:
        _, intruder_token = supabase_smoke_create_session(
            f"intruder-{uuid4().hex[:10]}@hiair.app",
            password,
        )
        intruder_headers = {"Authorization": f"Bearer {intruder_token}"}
    else:
        intruder_signup = client.post(
            "/api/auth/signup",
            json={"email": f"intruder-{uuid4().hex[:10]}@hiair.app", "password": password},
        )
        assert intruder_signup.status_code == 200, intruder_signup.text
        intruder_headers = {"Authorization": f"Bearer {intruder_signup.json()['access_token']}"}
    forbidden_history = client.get(
        "/api/risk/history",
        headers=intruder_headers,
        params={"profile_id": profile_id, "limit": 5},
    )
    assert forbidden_history.status_code == 403, forbidden_history.text

    privacy_export = client.get("/api/privacy/export", headers=auth_headers)
    assert privacy_export.status_code == 200, privacy_export.text
    assert privacy_export.json()["user_id"] == smoke_user_id
    assert "profiles" in privacy_export.json()["data"]

    delete_account = client.post(
        "/api/privacy/delete-account",
        headers=auth_headers,
        json={"confirmation": "DELETE"},
    )
    assert delete_account.status_code == 200, delete_account.text
    assert delete_account.json()["deleted"] is True

    assert_no_residual_personal_data(user_id=smoke_user_id, profile_ids=profile_ids)

    if _use_supabase_smoke_auth:
        me_after_delete = client.get("/api/auth/me", headers=auth_headers)
        assert me_after_delete.status_code == 200, me_after_delete.text
        assert me_after_delete.json().get("profile") is None
    else:
        login_after_delete = client.post("/api/auth/login", json={"email": email, "password": password})
        assert login_after_delete.status_code == 401, login_after_delete.text

        me_after_delete = client.get("/api/auth/me", headers=auth_headers)
        assert me_after_delete.status_code == 401, me_after_delete.text

    print("DB smoke flow passed.")


if __name__ == "__main__":
    run()
