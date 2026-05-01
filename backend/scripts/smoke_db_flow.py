import hashlib
import hmac
import json
import sys
from uuid import UUID
from uuid import uuid4

from fastapi.testclient import TestClient

from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.main import app
from app.core.settings import settings
from app.services.db import get_connection


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
    password = "strongpass123"

    signup = client.post("/api/auth/signup", json={"email": email, "password": password})
    assert signup.status_code == 200, signup.text
    access_token = signup.json()["access_token"]
    auth_headers = {"Authorization": f"Bearer {access_token}"}
    ops_headers = (
        {"X-Admin-Token": settings.notification_admin_token}
        if settings.notification_admin_token
        else {}
    )

    login = client.post("/api/auth/login", json={"email": email, "password": password})
    assert login.status_code == 200, login.text
    assert "access_token" in login.json()

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

    activate_sub = client.post(
        "/api/subscriptions/activate",
        headers=auth_headers,
        json={"plan_id": "basic_monthly", "use_trial": True},
    )
    assert activate_sub.status_code == 200, activate_sub.text

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
            "user_id": signup.json()["user_id"],
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

    metrics = client.get("/api/observability/metrics", headers=ops_headers)
    assert metrics.status_code == 200, metrics.text
    assert "total_requests" in metrics.json()

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
    assert privacy_export.json()["user_id"] == signup.json()["user_id"]
    assert "profiles" in privacy_export.json()["data"]

    delete_account = client.post(
        "/api/privacy/delete-account",
        headers=auth_headers,
        json={"confirmation": "DELETE"},
    )
    assert delete_account.status_code == 200, delete_account.text
    assert delete_account.json()["deleted"] is True

    assert_no_residual_personal_data(user_id=signup.json()["user_id"], profile_ids=profile_ids)

    login_after_delete = client.post("/api/auth/login", json={"email": email, "password": password})
    assert login_after_delete.status_code == 401, login_after_delete.text

    me_after_delete = client.get("/api/auth/me", headers=auth_headers)
    assert me_after_delete.status_code == 401, me_after_delete.text

    print("DB smoke flow passed.")


if __name__ == "__main__":
    run()
