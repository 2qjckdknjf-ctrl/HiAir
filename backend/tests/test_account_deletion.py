"""Integration tests for account deletion operations."""

from __future__ import annotations

from unittest.mock import patch

import pytest

from app.services.account_deletion import AccountDeletionError, delete_account
from app.services.supabase_account_admin import SupabaseAdminConfigError


@pytest.fixture(autouse=True)
def _ensure_operations_table() -> None:
    from scripts import init_db as init_db_module

    init_db_module.main()
    from app.services.db import get_connection

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM account_deletion_stage_events")
            cur.execute("DELETE FROM account_deletion_operations")
        conn.commit()


def test_delete_account_fails_closed_when_supabase_required_but_unconfigured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.services.supabase_account_admin import SupabaseAdminConfigError

    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: True)

    def _require() -> None:
        raise SupabaseAdminConfigError("missing supabase admin")

    monkeypatch.setattr("app.services.account_deletion.require_supabase_admin_config", _require)

    with pytest.raises(AccountDeletionError) as exc:
        delete_account(user_id="00000000-0000-0000-0000-000000000101")
    assert exc.value.http_status == 503


def test_delete_account_requires_apple_code_for_apple_users(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "apple",
    )
    monkeypatch.setattr(
        "app.services.account_deletion.require_apple_sign_in_config",
        lambda: None,
    )

    with pytest.raises(AccountDeletionError) as exc:
        delete_account(user_id="00000000-0000-0000-0000-000000000102")
    assert exc.value.http_status == 422
    assert exc.value.outcome.stage_map()["apple_revoke"] == "failed"


def test_delete_account_completes_for_non_apple_user(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "email",
    )
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )

    outcome = delete_account(user_id="00000000-0000-0000-0000-000000000103")
    assert outcome.completed is True
    assert outcome.stage_map()["apple_revoke"] == "not_applicable"
    assert outcome.stage_map()["public_data"] == "completed"


def test_delete_account_revokes_apple_before_public_data(monkeypatch: pytest.MonkeyPatch) -> None:
    order: list[str] = []
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "apple",
    )
    monkeypatch.setattr("app.services.account_deletion.require_apple_sign_in_config", lambda: None)
    monkeypatch.setattr(
        "app.services.account_deletion._revoke_apple_token",
        lambda _code, **_: order.append("apple"),
    )
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: order.append("public") or True,
    )

    outcome = delete_account(
        user_id="00000000-0000-0000-0000-000000000104",
        apple_authorization_code="auth-code",
    )
    assert outcome.completed is True
    assert order == ["apple", "public"]


def test_delete_account_is_idempotent_when_already_completed(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "email",
    )
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )

    first = delete_account(user_id="00000000-0000-0000-0000-000000000105")
    second = delete_account(user_id="00000000-0000-0000-0000-000000000105")
    assert first.completed is True
    assert second.completed is True
    assert first.operation_id == second.operation_id


def test_delete_account_retries_public_data_after_crash(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = {"count": 0}
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "email",
    )

    def _delete_user_data(**_: object) -> bool:
        calls["count"] += 1
        if calls["count"] == 1:
            raise RuntimeError("simulated crash during public_data")
        return True

    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        _delete_user_data,
    )

    with pytest.raises(AccountDeletionError) as first_exc:
        delete_account(user_id="00000000-0000-0000-0000-000000000106")
    assert first_exc.value.outcome.stage_map()["public_data"] == "failed"
    assert calls["count"] == 1

    outcome = delete_account(user_id="00000000-0000-0000-0000-000000000106")
    assert outcome.completed is True
    assert outcome.stage_map()["public_data"] == "completed"
    assert calls["count"] == 2


def test_delete_account_retries_supabase_auth_without_repeating_public_data(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    order: list[str] = []
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: True)
    monkeypatch.setattr("app.services.account_deletion.require_supabase_admin_config", lambda: None)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "email",
    )
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: order.append("public") or True,
    )

    def _delete_auth(user_id: str) -> bool:
        order.append("supabase")
        if order.count("supabase") == 1:
            raise RuntimeError("simulated supabase outage")
        return True

    monkeypatch.setattr("app.services.account_deletion.delete_auth_user", _delete_auth)

    with pytest.raises(AccountDeletionError):
        delete_account(user_id="00000000-0000-0000-0000-000000000107")
    assert order == ["public", "supabase"]

    outcome = delete_account(user_id="00000000-0000-0000-0000-000000000107")
    assert outcome.completed is True
    assert order == ["public", "supabase", "supabase"]
    assert outcome.stage_map()["apple_revoke"] == "not_applicable"
    assert outcome.stage_map()["public_data"] == "completed"
    assert outcome.stage_map()["supabase_auth"] == "completed"


def test_delete_account_does_not_repeat_apple_revoke_on_retry(monkeypatch: pytest.MonkeyPatch) -> None:
    apple_calls = {"count": 0}
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: False)
    monkeypatch.setattr(
        "app.services.account_deletion.detect_auth_provider",
        lambda _: "apple",
    )
    monkeypatch.setattr("app.services.account_deletion.require_apple_sign_in_config", lambda: None)

    def _revoke(_: str, **__: object) -> None:
        apple_calls["count"] += 1

    monkeypatch.setattr("app.services.account_deletion._revoke_apple_token", _revoke)
    monkeypatch.setattr(
        "app.services.account_deletion.privacy_repository.delete_user_data",
        lambda **_: True,
    )

    first = delete_account(
        user_id="00000000-0000-0000-0000-000000000108",
        apple_authorization_code="auth-code",
    )
    second = delete_account(
        user_id="00000000-0000-0000-0000-000000000108",
        apple_authorization_code="auth-code",
    )
    assert first.completed is True
    assert second.completed is True
    assert apple_calls["count"] == 1


def test_unknown_provider_is_redetected_after_supabase_config_restored(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Regression: unknown provider must not skip Apple revoke on retry."""
    config_ok = {"value": False}

    def _detect(_: str) -> str:
        return "apple" if config_ok["value"] else "unknown"

    monkeypatch.setattr("app.services.account_deletion.detect_auth_provider", _detect)
    monkeypatch.setattr("app.services.account_deletion.uses_supabase_auth", lambda: True)

    def _require() -> None:
        if not config_ok["value"]:
            raise SupabaseAdminConfigError("missing supabase admin")

    monkeypatch.setattr("app.services.account_deletion.require_supabase_admin_config", _require)

    with pytest.raises(AccountDeletionError) as first_exc:
        delete_account(user_id="00000000-0000-0000-0000-000000000109")
    assert first_exc.value.http_status == 503
    assert first_exc.value.outcome.stage_map().get("apple_revoke") != "failed"

    config_ok["value"] = True
    monkeypatch.setattr("app.services.account_deletion.require_apple_sign_in_config", lambda: None)

    with pytest.raises(AccountDeletionError) as second_exc:
        delete_account(user_id="00000000-0000-0000-0000-000000000109")
    assert second_exc.value.http_status == 422
    assert second_exc.value.outcome.stage_map()["apple_revoke"] == "failed"
    assert second_exc.value.outcome.stage_map()["apple_revoke"] != "not_applicable"
