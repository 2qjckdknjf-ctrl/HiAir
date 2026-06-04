from datetime import UTC, date, datetime

from fastapi.testclient import TestClient

from app.main import app
from app.models.wearable import (
    PersonalLoadSummary,
    WearableConsentResponse,
    WearableDailySummaryResponse,
    WearablePlatform,
    WearableSource,
    WearableTodayResponse,
)


def _auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def _sample_consent(user_id: str = "user-1") -> WearableConsentResponse:
    now = datetime.now(tz=UTC)
    return WearableConsentResponse(
        id="consent-1",
        userId=user_id,
        platform=WearablePlatform.IOS,
        source=WearableSource.APPLE_HEALTH,
        stepsEnabled=True,
        heartRateEnabled=True,
        restingHeartRateEnabled=True,
        hrvEnabled=False,
        sleepEnabled=False,
        consentVersion="wearables-v1",
        acceptedAt=now,
        revokedAt=None,
        isActive=True,
    )


def _sample_daily() -> WearableDailySummaryResponse:
    return WearableDailySummaryResponse(
        id="daily-1",
        date=date.today(),
        stepsTotal=8500,
        stepsGoal=10000,
        heartRateAvg=86,
        heartRateMin=58,
        heartRateMax=132,
        restingHeartRateAvg=66,
        restingHeartRateDelta=None,
        source=WearableSource.APPLE_HEALTH,
    )


def test_wearables_reject_unauthenticated() -> None:
    client = TestClient(app)
    response = client.get("/api/v1/wearables/today")
    assert response.status_code == 401


def test_consent_create(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.upsert_consent",
        lambda user_id, payload: _sample_consent(user_id),
    )

    client = TestClient(app)
    response = client.post(
        "/api/v1/wearables/consent",
        headers=_auth_headers(),
        json={
            "platform": "ios",
            "source": "apple_health",
            "stepsEnabled": True,
            "heartRateEnabled": True,
            "restingHeartRateEnabled": True,
            "hrvEnabled": False,
            "sleepEnabled": False,
            "consentVersion": "wearables-v1",
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["isActive"] is True


def test_consent_revoke(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    consent = _sample_consent()
    consent.isActive = False
    consent.revokedAt = datetime.now(tz=UTC)
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.revoke_consent",
        lambda user_id, source=None: consent,
    )

    client = TestClient(app)
    response = client.delete("/api/v1/wearables/consent", headers=_auth_headers())
    assert response.status_code == 200, response.text
    assert response.json()["revokedAt"] is not None


def test_daily_summary_without_consent_rejected(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.has_active_consent",
        lambda user_id, source: False,
    )

    client = TestClient(app)
    response = client.post(
        "/api/v1/wearables/daily-summary",
        headers=_auth_headers(),
        json={
            "date": str(date.today()),
            "stepsTotal": 8500,
            "source": "apple_health",
        },
    )
    assert response.status_code == 403, response.text


def test_daily_summary_upsert(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.has_active_consent",
        lambda user_id, source: True,
    )
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.upsert_daily_summary",
        lambda user_id, payload: _sample_daily(),
    )

    client = TestClient(app)
    response = client.post(
        "/api/v1/wearables/daily-summary",
        headers=_auth_headers(),
        json={
            "date": str(date.today()),
            "stepsTotal": 8500,
            "heartRateAvg": 86,
            "source": "apple_health",
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["stepsTotal"] == 8500


def test_invalid_daily_summary_rejected(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    client = TestClient(app)
    response = client.post(
        "/api/v1/wearables/daily-summary",
        headers=_auth_headers(),
        json={
            "date": str(date.today()),
            "stepsTotal": 200_000,
            "source": "apple_health",
        },
    )
    assert response.status_code == 422, response.text


def test_get_today(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.wearables.wearable_service.build_today_response",
        lambda user_id: WearableTodayResponse(
            consent=_sample_consent(user_id),
            dailySummary=_sample_daily(),
            personalLoad=PersonalLoadSummary(
                score=15,
                level="low",
                explanations=["Сегодня высокая активность на фоне жары."],
                reasonCodes=["elevated_steps_heat"],
            ),
        ),
    )

    client = TestClient(app)
    response = client.get("/api/v1/wearables/today", headers=_auth_headers())
    assert response.status_code == 200, response.text
    assert response.json()["dailySummary"]["stepsTotal"] == 8500


def test_delete_health_data(monkeypatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.delete_all_summaries",
        lambda user_id: (3, 12),
    )
    monkeypatch.setattr(
        "app.api.wearables.wearable_repository.revoke_consent",
        lambda user_id, source=None: _sample_consent(user_id),
    )

    client = TestClient(app)
    response = client.delete("/api/v1/wearables/data", headers=_auth_headers())
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deletedDaily"] == 3
    assert body["deletedHourly"] == 12
    assert body["consentRevoked"] is True
