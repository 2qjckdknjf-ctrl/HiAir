"""Unit and integration-style tests for account deletion orchestration."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.account_deletion import (
    AccountDeletionError,
    AccountDeletionOutcome,
    DeletionStage,
    StageResult,
    StageStatus,
    delete_account,
)


def _completed_outcome(**stage_overrides: StageStatus) -> AccountDeletionOutcome:
    stages = [
        StageResult(DeletionStage.PUBLIC_DATA, stage_overrides.get("public", StageStatus.COMPLETED)),
        StageResult(DeletionStage.SUPABASE_AUTH, stage_overrides.get("auth", StageStatus.SKIPPED)),
        StageResult(DeletionStage.APPLE_REVOKE, stage_overrides.get("apple", StageStatus.NOT_APPLICABLE)),
    ]
    return AccountDeletionOutcome(completed=True, stages=stages)


def test_delete_account_full_success(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: True,
    )

    class _Response:
        status_code = 204

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.delete.return_value = _Response()
        outcome = delete_account(user_id="user-1")

    assert outcome.completed is True
    assert outcome.stage_map()["public_data"] == "completed"
    assert outcome.stage_map()["supabase_auth"] == "completed"


def test_delete_account_idempotent_when_already_deleted(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: False,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: True,
    )

    class _Response:
        status_code = 404

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.delete.return_value = _Response()
        outcome = delete_account(user_id="user-1")

    assert outcome.completed is True
    assert outcome.stage_map()["public_data"] == "not_applicable"
    assert outcome.stage_map()["supabase_auth"] == "not_applicable"


def test_delete_account_fails_when_public_data_delete_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    from psycopg import Error as PsycopgError

    def _raise(**_: object) -> bool:
        raise PsycopgError("db down")

    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        _raise,
    )

    with pytest.raises(AccountDeletionError) as exc:
        delete_account(user_id="user-1")

    assert exc.value.http_status == 503
    assert exc.value.outcome.stage_map()["public_data"] == "failed"


def test_delete_account_fails_when_supabase_admin_delete_fails(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: True,
    )

    class _Response:
        status_code = 500

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.delete.return_value = _Response()
        with pytest.raises(AccountDeletionError) as exc:
            delete_account(user_id="user-1")

    assert exc.value.http_status == 503
    assert exc.value.outcome.stage_map()["supabase_auth"] == "failed"


def test_delete_account_requires_apple_code_when_flag_set(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: False,
    )

    with pytest.raises(AccountDeletionError) as exc:
        delete_account(user_id="user-1", require_apple_revoke=True)

    assert exc.value.outcome.stage_map()["apple_revoke"] == "failed"


def test_delete_account_revokes_apple_token(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: False,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._apple_client_secret",
        lambda: "client-secret",
    )

    token_response = SimpleNamespace(status_code=200, json=lambda: {"refresh_token": "rt-1"})
    revoke_response = SimpleNamespace(status_code=200)

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.post.side_effect = [token_response, revoke_response]
        outcome = delete_account(user_id="user-1", apple_authorization_code="auth-code")

    assert outcome.completed is True
    assert outcome.stage_map()["apple_revoke"] == "completed"


def test_delete_account_apple_revoke_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: False,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._apple_client_secret",
        lambda: "client-secret",
    )

    token_response = SimpleNamespace(status_code=200, json=lambda: {"refresh_token": "rt-1"})
    revoke_response = SimpleNamespace(status_code=400)
    monkeypatch.setattr("app.services.account_deletion._MAX_HTTP_RETRIES", 1)

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.post.side_effect = [token_response, revoke_response]
        with pytest.raises(AccountDeletionError) as exc:
            delete_account(user_id="user-1", apple_authorization_code="auth-code")

    assert exc.value.outcome.stage_map()["apple_revoke"] == "failed"


def test_delete_account_apple_revoke_skips_without_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: False,
    )
    monkeypatch.setattr("app.services.account_deletion._apple_client_secret", lambda: "")

    with pytest.raises(AccountDeletionError) as exc:
        delete_account(user_id="user-1", apple_authorization_code="auth-code")

    assert exc.value.outcome.stage_map()["apple_revoke"] == "failed"


def test_delete_account_retries_supabase_on_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )
    monkeypatch.setattr(
        "app.services.account_deletion._supabase_admin_configured",
        lambda: True,
    )
    monkeypatch.setattr("app.services.account_deletion.time.sleep", lambda _: None)

    class _Response:
        status_code = 204

    with patch("app.services.account_deletion.httpx.Client") as client_cls:
        client = client_cls.return_value.__enter__.return_value
        client.delete.side_effect = [httpx.TimeoutException("timeout"), _Response()]
        outcome = delete_account(user_id="user-1")

    assert outcome.completed is True
    assert client.delete.call_count == 2


def test_delete_account_api_returns_stage_payload(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")
    monkeypatch.setattr(
        "app.api.privacy.account_deletion_service.delete_account",
        lambda **_: _completed_outcome(),
    )

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["deleted"] is True
    assert body["stages"]["public_data"] == "completed"


def test_delete_account_api_returns_503_on_partial_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    def _raise(**_: object) -> AccountDeletionOutcome:
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                stages=[
                    StageResult(DeletionStage.PUBLIC_DATA, StageStatus.COMPLETED),
                    StageResult(DeletionStage.SUPABASE_AUTH, StageStatus.FAILED, "http_500"),
                ],
                recovery_hint="retry",
            ),
            http_status=503,
        )

    monkeypatch.setattr("app.api.privacy.account_deletion_service.delete_account", _raise)

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "DELETE"},
    )
    assert response.status_code == 503, response.text
    detail = response.json()["detail"]
    assert detail["stages"]["supabase_auth"] == "failed"


def test_delete_account_api_rejects_invalid_confirmation(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.api.deps.user_repository.user_exists", lambda _: True)
    monkeypatch.setattr("app.api.deps.decode_access_token", lambda _: "user-1")

    client = TestClient(app)
    response = client.post(
        "/api/privacy/delete-account",
        headers={"Authorization": "Bearer token"},
        json={"confirmation": "delete"},
    )
    assert response.status_code == 422
