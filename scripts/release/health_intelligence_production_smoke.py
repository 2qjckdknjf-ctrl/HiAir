#!/usr/bin/env python3
"""Production Health Intelligence smoke for https://api.hiair.io.

Uses ephemeral Supabase signup + synthetic aggregates only.
Never prints exact health metric values.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4


def _load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key and key not in os.environ:
            os.environ[key] = value.strip().strip("'").strip('"')


def _request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    body: dict | None = None,
    timeout: int = 60,
) -> tuple[int, dict | list | str]:
    payload = None
    merged = {"User-Agent": "HiAir-Health-Smoke/1.0", "Accept": "application/json"}
    if headers:
        merged.update(headers)
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
        merged["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=payload, headers=merged, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(raw)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed: dict | list | str = json.loads(raw)
        except json.JSONDecodeError:
            parsed = raw
        return exc.code, parsed


def _ok(name: str, detail: str = "") -> None:
    suffix = f" ({detail})" if detail else ""
    print(f"{name}: PASS{suffix}")


def _fail(name: str, detail: str) -> None:
    print(f"{name}: FAIL {detail}")


def _supabase_signup(base: str, anon_key: str, email: str, password: str) -> tuple[str, str]:
    status, payload = _request(
        "POST",
        f"{base.rstrip('/')}/auth/v1/signup",
        headers={"apikey": anon_key, "Authorization": f"Bearer {anon_key}"},
        body={"email": email, "password": password},
    )
    if status not in (200, 201) or not isinstance(payload, dict):
        raise RuntimeError(f"signup status={status}")
    user = payload.get("user") or {}
    user_id = str(user.get("id") or "")
    access_token = str(payload.get("access_token") or "")
    if not user_id or not access_token:
        raise RuntimeError("signup missing token")
    return user_id, access_token


def _grant_premium(database_url: str, user_id: str) -> None:
    import psycopg
    from psycopg.rows import dict_row

    until = datetime.now(tz=timezone.utc) + timedelta(days=2)
    with psycopg.connect(database_url, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_entitlements (
                    user_id, plan, is_premium, premium_until, source_subscription_id,
                    max_profiles, extended_forecast_enabled, custom_alerts_enabled,
                    export_reports_enabled, advanced_insights_enabled,
                    wearable_insights_enabled, priority_notifications_enabled, updated_at
                )
                VALUES (
                    %s, 'premium', true, %s, NULL,
                    5, true, true, true, true, true, true, NOW()
                )
                ON CONFLICT (user_id) DO UPDATE SET
                    plan = EXCLUDED.plan,
                    is_premium = EXCLUDED.is_premium,
                    premium_until = EXCLUDED.premium_until,
                    source_subscription_id = EXCLUDED.source_subscription_id,
                    max_profiles = EXCLUDED.max_profiles,
                    extended_forecast_enabled = EXCLUDED.extended_forecast_enabled,
                    custom_alerts_enabled = EXCLUDED.custom_alerts_enabled,
                    export_reports_enabled = EXCLUDED.export_reports_enabled,
                    advanced_insights_enabled = EXCLUDED.advanced_insights_enabled,
                    wearable_insights_enabled = EXCLUDED.wearable_insights_enabled,
                    priority_notifications_enabled = EXCLUDED.priority_notifications_enabled,
                    updated_at = NOW()
                """,
                (user_id, until),
            )
        conn.commit()


def _metric(metric_type: str, unit: str, *, total: float | None = None, avg: float | None = None) -> dict:
    item: dict = {
        "metricType": metric_type,
        "unit": unit,
        "sampleCount": 1,
        "qualityState": "ok",
    }
    if total is not None:
        item["valueTotal"] = total
    if avg is not None:
        item["valueAvg"] = avg
    if metric_type == "hrv_sdnn":
        item["hrvMethod"] = "sdnn"
    return item


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    _load_dotenv(root / "backend" / ".env.local")

    parser = argparse.ArgumentParser(description="Health Intelligence production smoke")
    parser.add_argument("--base-url", default=os.getenv("HIAIR_API_BASE_URL", "https://api.hiair.io"))
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL", "").strip())
    parser.add_argument("--supabase-anon-key", default=os.getenv("SUPABASE_ANON_KEY", "").strip())
    parser.add_argument("--database-url", default=os.getenv("DATABASE_URL", "").strip())
    parser.add_argument("--expect-sha", default=os.getenv("EXPECT_DEPLOY_SHA", "").strip())
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    failures = 0

    status, health = _request("GET", f"{base}/api/health")
    if status != 200 or not isinstance(health, dict) or health.get("status") != "ok":
        _fail("health", f"status={status}")
        return 1
    deploy_sha = str(health.get("deploy_git_sha") or "")
    if args.expect_sha and not deploy_sha.startswith(args.expect_sha[:7]):
        _fail("deploy_git_sha", f"expected prefix {args.expect_sha[:7]} got {deploy_sha[:12]}")
        failures += 1
    else:
        _ok("deploy_git_sha", deploy_sha[:12] + "…")

    for path, method in (
        ("/api/v1/health/summary", "GET"),
        ("/api/v1/health/availability", "GET"),
        ("/api/v1/health/sync", "POST"),
        ("/api/v1/health/data", "DELETE"),
    ):
        st, _ = _request(method, f"{base}{path}", body={} if method == "POST" else None)
        if st != 401:
            _fail(f"unauth{path}", f"expected 401 got {st}")
            failures += 1
        else:
            _ok(f"unauth{path}")

    if not args.supabase_url or not args.supabase_anon_key:
        print("authenticated: SKIP missing SUPABASE_URL/ANON")
        return 1 if failures else 0

    email = f"health-smoke-{uuid4().hex[:10]}@hiair.app"
    password = f"StrongPass{uuid4().hex[:8]}!"
    try:
        user_id, token = _supabase_signup(args.supabase_url, args.supabase_anon_key, email, password)
    except RuntimeError as exc:
        _fail("signup", str(exc))
        return 1
    auth = {"Authorization": f"Bearer {token}"}
    _ok("signup", f"user={user_id[:8]}…")

    st, avail = _request("GET", f"{base}/api/v1/health/availability", headers=auth)
    if st != 200:
        _fail("availability-empty", f"status={st}")
        failures += 1
    else:
        _ok("availability-empty")

    st, summary = _request("GET", f"{base}/api/v1/health/summary", headers=auth)
    if st != 200 or not isinstance(summary, dict):
        _fail("summary-empty", f"status={st}")
        failures += 1
    else:
        metrics = summary.get("metrics") or []
        if metrics:
            _fail("summary-empty", "expected no metrics before sync")
            failures += 1
        else:
            _ok("summary-empty")

    st, profile = _request(
        "POST",
        f"{base}/api/profiles",
        headers=auth,
        body={
            "persona_type": "adult",
            "sensitivity_level": "medium",
            "home_lat": 41.3874,
            "home_lon": 2.1686,
        },
    )
    if st not in (200, 201) or not isinstance(profile, dict) or not profile.get("id"):
        _fail("profile-create", f"status={st}")
        return 1
    profile_id = str(profile["id"])
    _ok("profile-create")

    st, consent = _request(
        "POST",
        f"{base}/api/v1/wearables/consent",
        headers=auth,
        body={
            "platform": "ios",
            "source": "apple_health",
            "stepsEnabled": True,
            "heartRateEnabled": True,
            "restingHeartRateEnabled": True,
            "hrvEnabled": True,
            "sleepEnabled": True,
            "sleepStagesEnabled": True,
            "activityEnabled": True,
            "workoutsEnabled": True,
            "temperatureEnabled": True,
            "fitnessEnabled": True,
            "bodyMetricsEnabled": True,
            "sensitiveMetricsEnabled": False,
            "consentVersion": "health-intelligence-v1",
        },
    )
    if st not in (200, 201) or not isinstance(consent, dict) or not consent.get("isActive"):
        _fail("consent", f"status={st}")
        return 1
    _ok("consent")

    today = date.today()
    accepted_days = 0
    for offset in range(14):
        day = today - timedelta(days=offset)
        # Synthetic aggregates only — values are disposable smoke fixtures.
        steps = 4000 + (offset * 250)
        body = {
            "profileId": profile_id,
            "localDate": day.isoformat(),
            "timezone": "Europe/Madrid",
            "platform": "ios",
            "source": "apple_health",
            "idempotencyKey": f"smoke-{user_id[:8]}-{day.isoformat()}",
            "metrics": [
                _metric("steps", "count", total=float(steps)),
                _metric("active_energy", "kcal", total=220.0 + offset),
                _metric("basal_energy", "kcal", total=1400.0),
                _metric("resting_heart_rate", "bpm", avg=58.0 + (offset % 3)),
                _metric("hrv_sdnn", "ms", avg=42.0 + (offset % 5)),
            ],
            "sleep": {
                "localDate": day.isoformat(),
                "totalMinutes": 390 + (offset % 40),
                "deepMinutes": 70,
                "remMinutes": 80,
                "coreLightMinutes": 220,
                "qualityState": "ok",
            },
        }
        st, sync = _request(
            "POST",
            f"{base}/api/v1/health/sync",
            headers={**auth, "Idempotency-Key": body["idempotencyKey"]},
            body=body,
        )
        if st == 200 and isinstance(sync, dict) and int(sync.get("acceptedMetrics") or 0) >= 1:
            accepted_days += 1
        elif offset == 0:
            _fail("sync-today", f"status={st} body_keys={list(sync) if isinstance(sync, dict) else type(sync)}")
            failures += 1
    if accepted_days < 14:
        _fail("sync-window", f"accepted_days={accepted_days}")
        failures += 1
    else:
        _ok("sync-window", f"days={accepted_days}")

    # Duplicate sync should remain successful without inventing new identity.
    dup_key = f"smoke-{user_id[:8]}-{today.isoformat()}"
    st, dup = _request(
        "POST",
        f"{base}/api/v1/health/sync",
        headers={**auth, "Idempotency-Key": dup_key},
        body={
            "profileId": profile_id,
            "localDate": today.isoformat(),
            "timezone": "Europe/Madrid",
            "platform": "ios",
            "source": "apple_health",
            "idempotencyKey": dup_key,
            "metrics": [_metric("steps", "count", total=5000.0)],
        },
    )
    if st != 200:
        _fail("sync-duplicate", f"status={st}")
        failures += 1
    else:
        _ok("sync-duplicate")

    st, bad_unit = _request(
        "POST",
        f"{base}/api/v1/health/sync",
        headers=auth,
        body={
            "localDate": today.isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [{"metricType": "steps", "unit": "bpm", "valueTotal": 10, "qualityState": "ok"}],
        },
    )
    if st not in (400, 422):
        _fail("sync-invalid-unit", f"expected 400/422 got {st}")
        failures += 1
    else:
        _ok("sync-invalid-unit")

    st, wrong = _request(
        "POST",
        f"{base}/api/v1/health/sync",
        headers=auth,
        body={
            "profileId": str(uuid4()),
            "localDate": today.isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [_metric("steps", "count", total=10.0)],
        },
    )
    if st not in (403, 404):
        _fail("sync-wrong-profile", f"expected 403/404 got {st}")
        failures += 1
    else:
        _ok("sync-wrong-profile", f"status={st}")

    st, summary2 = _request(
        "GET",
        f"{base}/api/v1/health/summary?local_date={today.isoformat()}",
        headers=auth,
    )
    if st != 200 or not isinstance(summary2, dict):
        _fail("summary-after-sync", f"status={st}")
        failures += 1
    else:
        metric_types = {m.get("metricType") for m in (summary2.get("metrics") or []) if isinstance(m, dict)}
        # Count only — never print values.
        if "steps" not in metric_types:
            _fail("summary-after-sync", "steps missing")
            failures += 1
        else:
            _ok("summary-after-sync", f"metric_types={len(metric_types)}")

    st, today_payload = _request("GET", f"{base}/api/v1/wearables/today", headers=auth)
    if st != 200 or not isinstance(today_payload, dict):
        _fail("personal-load", f"status={st}")
        failures += 1
    else:
        load = today_payload.get("personalLoad") or today_payload.get("personal_load")
        if not isinstance(load, dict) or "score" not in load:
            _fail("personal-load", "missing personalLoad.score")
            failures += 1
        else:
            _ok("personal-load", f"level={load.get('level')}")

    st, insights_free = _request(
        "GET",
        f"{base}/api/v1/health/insights?profile_id={profile_id}&window_days=30&language=en",
        headers=auth,
    )
    if st != 402:
        _fail("insights-free-gate", f"expected 402 got {st}")
        failures += 1
    else:
        _ok("insights-free-gate")

    if not args.database_url:
        _fail("premium-grant", "DATABASE_URL missing")
        failures += 1
    else:
        try:
            _grant_premium(args.database_url, user_id)
            _ok("premium-grant")
        except Exception as exc:  # noqa: BLE001 — smoke reports and continues
            _fail("premium-grant", str(exc)[:120])
            failures += 1

    for window in (7, 30):
        st, insights = _request(
            "GET",
            f"{base}/api/v1/health/insights?profile_id={profile_id}&window_days={window}&language=en",
            headers=auth,
        )
        if st != 200 or not isinstance(insights, dict):
            _fail(f"insights-{window}", f"status={st}")
            failures += 1
            continue
        status_block = insights.get("healthDataStatus") or {}
        if status_block.get("consentActive") is not True:
            _fail(f"insights-{window}", "consentActive!=true")
            failures += 1
        else:
            trend_n = len(insights.get("trends") or [])
            assoc_n = len(insights.get("associations") or [])
            insuff_n = len(insights.get("insufficientData") or [])
            _ok(f"insights-{window}", f"trends={trend_n} associations={assoc_n} insufficient={insuff_n}")

    st, risk = _request(
        "GET",
        f"{base}/api/air/current-risk?profileId={profile_id}",
        headers=auth,
        timeout=90,
    )
    if st != 200 or not isinstance(risk, dict):
        _fail("ai-current-risk", f"status={st}")
        failures += 1
    else:
        source = str(risk.get("explanationSource") or "")
        explanation = str(risk.get("explanation") or "")
        banned = ("diagnos", "disease", "emergency", "you have")
        if any(token in explanation.lower() for token in banned):
            _fail("ai-current-risk", "possible medical wording")
            failures += 1
        elif not explanation:
            _fail("ai-current-risk", "empty explanation")
            failures += 1
        else:
            _ok("ai-current-risk", f"source={source} chars={len(explanation)}")

    # Consent revoke then sync denied
    st, _ = _request("DELETE", f"{base}/api/v1/wearables/consent?source=apple_health", headers=auth)
    if st not in (200, 204):
        # Some deployments return 200 with body
        if st != 200:
            _fail("consent-revoke", f"status={st}")
            failures += 1
        else:
            _ok("consent-revoke")
    else:
        _ok("consent-revoke")

    st, denied = _request(
        "POST",
        f"{base}/api/v1/health/sync",
        headers=auth,
        body={
            "localDate": today.isoformat(),
            "platform": "ios",
            "source": "apple_health",
            "metrics": [_metric("steps", "count", total=1.0)],
        },
    )
    if st != 403:
        _fail("sync-after-revoke", f"expected 403 got {st}")
        failures += 1
    else:
        _ok("sync-after-revoke")

    # Re-consent for delete path (delete also revokes)
    _request(
        "POST",
        f"{base}/api/v1/wearables/consent",
        headers=auth,
        body={
            "platform": "ios",
            "source": "apple_health",
            "stepsEnabled": True,
            "heartRateEnabled": True,
            "restingHeartRateEnabled": True,
            "hrvEnabled": True,
            "sleepEnabled": True,
            "activityEnabled": True,
            "consentVersion": "health-intelligence-v1",
        },
    )
    st, deleted = _request("DELETE", f"{base}/api/v1/health/data", headers=auth)
    if st != 200 or not isinstance(deleted, dict) or deleted.get("consentRevoked") is not True:
        _fail("delete-health", f"status={st}")
        failures += 1
    else:
        _ok(
            "delete-health",
            f"metrics={deleted.get('deletedMetrics')} sleep={deleted.get('deletedSleep')}",
        )

    st, export = _request("GET", f"{base}/api/privacy/export", headers=auth)
    if st == 402:
        _fail("privacy-export", "premium gated")
        failures += 1
    elif st != 200:
        _fail("privacy-export", f"status={st}")
        failures += 1
    else:
        _ok("privacy-export")

    if failures:
        print(f"health_intelligence_production_smoke: FAIL failures={failures}")
        return 1
    print("health_intelligence_production_smoke: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
