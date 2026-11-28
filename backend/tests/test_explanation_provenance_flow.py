"""Exercise the real explanation gate through each production caller, without egress."""
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.api import air as air_api
from app.models.air import ProfileType, UserProfileContext
from app.models.forecast import EnvironmentalForecast, EnvironmentalForecastPoint
from app.models.risk import EnvironmentSnapshot
from app.services import ai_explanation_service, ai_report_service, air_environment_service, air_repository, briefing_service


@pytest.fixture
def explanation_flow(monkeypatch):
    profile = UserProfileContext(profile_id="profile-1", user_id="user-1", profile_type=ProfileType.ADULT_DEFAULT, home_lat=41.39, home_lon=2.17)
    calls = []
    writes = []

    class Client:
        def __init__(self, **kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def post(self, *args, **kwargs):
            calls.append(kwargs)
            return SimpleNamespace(
                raise_for_status=lambda: None,
                json=lambda: {"choices": [{"message": {"content": "Keep outdoor effort shorter today."}}]},
            )

    monkeypatch.setattr(ai_explanation_service.httpx, "Client", Client)
    monkeypatch.setattr(ai_explanation_service, "settings", SimpleNamespace(
        openai_api_key="test-only", openai_model="test-model",
        openai_base_url="https://api.openai.com/v1/chat/completions",
        openai_prompt_version="test-v1", openai_rate_limit_per_minute=0,
        openai_http_timeout_seconds=1, openai_max_tokens=120,
    ))
    monkeypatch.setattr(ai_explanation_service, "ensure_prompt_version", lambda **kwargs: None)
    monkeypatch.setattr(ai_explanation_service, "save_explanation_event", lambda **kwargs: "event-1")
    monkeypatch.setattr(air_api.air_repository, "get_profile_context", lambda _: profile)
    monkeypatch.setattr(air_api.air_repository, "save_environment_snapshot", lambda value: writes.append(value) or "snapshot-1")
    monkeypatch.setattr(air_api.air_repository, "save_risk_assessment", lambda *args: "assessment-1")
    monkeypatch.setattr(air_api.air_repository, "save_recommendation", lambda **kwargs: None)
    monkeypatch.setattr(air_api.settings_repository, "get_user_settings", lambda _: SimpleNamespace(preferred_language="en"))
    monkeypatch.setattr(air_api.wearable_service, "build_personal_load_input", lambda *args: None)
    monkeypatch.setattr(air_api.wearable_service, "build_today_response", lambda _: SimpleNamespace(personalLoad=None))
    monkeypatch.setattr(air_api.wearable_repository, "get_active_consent", lambda _: None)
    monkeypatch.setattr(ai_report_service, "_health_observations", lambda *args: [])
    monkeypatch.setattr(briefing_service.briefing_repository, "get_user_profile_ids", lambda _: [profile.profile_id])

    def run(caller, *, snapshot, forecast=None):
        monkeypatch.setattr(air_environment_service, "resolve_environment_snapshot", lambda *args, **kwargs: snapshot)
        monkeypatch.setattr(air_api, "_load_forecast_or_none", lambda *args: forecast)
        monkeypatch.setattr(ai_report_service, "get_forecast", lambda *args: forecast)
        monkeypatch.setattr(briefing_service, "get_forecast", lambda *args: forecast)
        if caller == "recompute":
            return air_api._compute_and_persist(profile.profile_id, profile.user_id, True, allow_llm=True)
        if caller == "report":
            return ai_report_service.build_ai_report(user_id=profile.user_id, profile_id=profile.profile_id, kind="morning")
        return briefing_service.compose_briefing(profile.user_id)

    return run, calls, writes


def snapshot(**changes):
    values = dict(temperature_c=26, humidity_percent=50, aqi=65, pm25=12, ozone=60,
                  source="live", received_at=datetime.now(timezone.utc).isoformat(), data_quality="complete")
    values.update(changes)
    return EnvironmentSnapshot(**values)


@pytest.mark.parametrize("caller", ["recompute", "report", "briefing"])
@pytest.mark.parametrize("case", ["stale_forecast", "stale_snapshot", "unavailable_snapshot", "unknown_receipt", "unavailable_current", "stale_pollen", "stale_smoke", "synthetic_snapshot"])
def test_actual_callers_never_send_stale_or_unavailable_environment_to_llm(explanation_flow, caller, case):
    run, calls, writes = explanation_flow
    current = snapshot()
    forecast = None
    if case in {"stale_forecast", "unavailable_current", "stale_pollen", "stale_smoke"}:
        point = EnvironmentalForecastPoint(
            timestamp=current.received_at, timezone="UTC", lat=41.39, lon=2.17,
            temperature_c=26, relative_humidity_pct=50,
            aqi=65 if case != "unavailable_current" else None,
            pm25_ugm3=12 if case != "unavailable_current" else None,
            ozone_ugm3=60 if case != "unavailable_current" else None,
            quality="complete" if case != "unavailable_current" else "unavailable",
        )
        forecast = EnvironmentalForecast(current=point, timezone="UTC", lat=41.39, lon=2.17,
            generated_at=current.received_at, fetched_at=current.received_at,
            freshness="stale" if case == "stale_forecast" else "live", quality="complete")
        if case in {"stale_pollen", "stale_smoke"}:
            metric = "pollen_grains_m3" if case == "stale_pollen" else "wildfire_pm10"
            current = snapshot(source="cached", received_at=(datetime.now(timezone.utc) - timedelta(days=2)).isoformat(), **{metric: 100})
    elif case == "stale_snapshot":
        current = snapshot(source="cached", received_at=(datetime.now(timezone.utc) - timedelta(days=2)).isoformat())
    elif case == "unavailable_snapshot":
        current = snapshot(aqi=None, pm25=None, ozone=None, data_quality="unavailable")
    elif case == "synthetic_snapshot":
        current = snapshot(source="sample")
    else:
        current = snapshot(source="cached", received_at=None)

    result = run(caller, snapshot=current, forecast=forecast)
    assert result, "deterministic advice remains available"
    assert calls == [], "the real provider boundary must remain untouched"
    assert writes == [], "unverified inputs must not be republished into a fresh cache row"


@pytest.mark.parametrize("caller", ["recompute", "report", "briefing"])
def test_fresh_complete_snapshot_still_allows_explanations_when_forecast_is_down(explanation_flow, caller):
    run, calls, _ = explanation_flow
    assert run(caller, snapshot=snapshot())
    assert len(calls) == 1


def test_missing_quality_or_freshness_is_not_implicit_authorization():
    for quality, freshness in [(None, None), ("complete", None), (None, "live"), ("unknown", "live")]:
        assert not ai_explanation_service.llm_allowed_for_data_quality(data_quality=quality, freshness=freshness)
    assert ai_explanation_service.llm_allowed_for_data_quality(data_quality="partial", freshness="cached")


def test_snapshot_mapping_preserves_quality_and_receipt_age():
    old = snapshot(source="cached", received_at=(datetime.now(timezone.utc) - timedelta(days=2)).isoformat())
    mapped = air_environment_service._snapshot_to_environmental(old, 41.39, 2.17, "UTC")
    assert getattr(mapped, "data_quality", None) == "complete"
    assert getattr(mapped, "freshness", None) == "stale"
    assert mapped.timestamp == old.received_at


def test_cache_mapping_and_persistence_do_not_renew_the_original_receipt(monkeypatch):
    now = datetime.now(timezone.utc)
    original = now - timedelta(seconds=120)
    row = dict(temperature_c=26, humidity_percent=50, aqi=65, pm25=12, ozone=60,
               source="cached", timestamp_utc=original)

    class Clock(datetime):
        @classmethod
        def now(cls, tz=None):
            return now

    class Cursor:
        cutoff = None

        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def execute(self, query, params):
            if query.strip().startswith("SELECT"):
                self.cutoff = params[1]
            else:
                row["timestamp_utc"] = datetime.fromisoformat(params[2])

        def fetchone(self):
            return dict(row) if row["timestamp_utc"] >= self.cutoff else None

        def cursor(self):
            return self

    monkeypatch.setattr(air_repository, "get_connection", lambda: Cursor())
    monkeypatch.setattr(air_repository, "datetime", Clock)
    monkeypatch.setattr(air_environment_service, "datetime", Clock)
    cached = air_repository.get_latest_environment_snapshot(41.39, 2.17, 300)
    assert cached is not None and cached.received_at is not None
    mapped = air_environment_service._snapshot_to_environmental(cached, 41.39, 2.17, "UTC")
    assert mapped.freshness == "cached"
    air_repository.save_environment_snapshot(mapped)
    assert row["timestamp_utc"] == original
    now += timedelta(seconds=240)
    assert air_repository.get_latest_environment_snapshot(41.39, 2.17, 300) is None
