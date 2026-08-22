"""Fail-closed account deletion with durable operations and ordered stages."""

from __future__ import annotations

import hashlib
import logging
import time
import uuid
from dataclasses import dataclass, field
from enum import StrEnum
from typing import Any

import httpx
import jwt
from psycopg import Error as PsycopgError

from app.core.settings import settings
from app.services.apple_sign_in_credentials import (
    AppleSignInConfigError,
    require_apple_sign_in_config,
    temporary_apple_p8_path,
)
from app.services.db import get_connection
import app.services.privacy_repository as privacy_repository
from app.services.supabase_account_admin import (
    SupabaseAdminConfigError,
    delete_auth_user,
    detect_auth_provider,
    fetch_auth_user,
    require_supabase_admin_config,
    uses_supabase_auth,
)

logger = logging.getLogger(__name__)

_OPERATION_LOCK_KEY = 9_314_159_265
_HTTP_TIMEOUT_SECONDS = 20.0
_MAX_HTTP_RETRIES = 2
_CONFIRMED_AUTH_PROVIDERS = frozenset({"apple", "google", "email"})
_UNCONFIRMED_AUTH_PROVIDER = "unknown"


class DeletionStage(StrEnum):
    APPLE_REVOKE = "apple_revoke"
    PUBLIC_DATA = "public_data"
    SUPABASE_AUTH = "supabase_auth"


class StageStatus(StrEnum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"
    NOT_APPLICABLE = "not_applicable"


class OperationStatus(StrEnum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass(frozen=True)
class StageResult:
    stage: DeletionStage
    status: StageStatus
    detail: str | None = None


@dataclass
class AccountDeletionOutcome:
    completed: bool
    operation_id: str
    stages: list[StageResult] = field(default_factory=list)
    recovery_hint: str | None = None

    def stage_map(self) -> dict[str, str]:
        return {result.stage.value: result.status.value for result in self.stages}


class AccountDeletionError(Exception):
    def __init__(self, outcome: AccountDeletionOutcome, http_status: int) -> None:
        super().__init__(outcome.recovery_hint or "account deletion failed")
        self.outcome = outcome
        self.http_status = http_status


@dataclass
class _OperationRow:
    operation_id: str
    user_id_hash: str
    auth_provider: str
    status: str
    apple_revoke_status: str
    public_data_status: str
    supabase_auth_status: str


def deletion_requirements(*, user_id: str) -> dict[str, object]:
    uid = (user_id or "").strip()
    if not uid:
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                operation_id="",
                stages=[],
                recovery_hint="Authenticated user id is required.",
            ),
            http_status=401,
        )

    user_hash = _hash_user_id(uid)
    with get_connection() as conn:
        with conn.cursor() as cur:
            operation = _load_or_create_operation(cur, user_hash=user_hash, user_id=uid)
            conn.commit()
            auth_provider = _resolve_auth_provider(
                cur,
                operation,
                uid,
                allow_unconfirmed=True,
            )
            conn.commit()
            operation = _reload_operation(cur, operation.operation_id)

    stages = _stage_results_from_operation(operation)
    in_progress = operation.status in {
        OperationStatus.PENDING.value,
        OperationStatus.IN_PROGRESS.value,
        OperationStatus.FAILED.value,
    }
    return {
        "requires_apple_authorization_code": auth_provider == "apple",
        "auth_provider": auth_provider,
        "operation_id": operation.operation_id,
        "in_progress": in_progress and not _operation_is_complete(operation),
        "stages": {result.stage.value: result.status.value for result in stages},
        "recovery_hint": _recovery_hint(stages, completed=operation.status == OperationStatus.COMPLETED.value),
    }


def delete_account(
    *,
    user_id: str,
    apple_authorization_code: str | None = None,
) -> AccountDeletionOutcome:
    uid = (user_id or "").strip()
    if not uid:
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                operation_id="",
                stages=[
                    StageResult(DeletionStage.PUBLIC_DATA, StageStatus.FAILED, "missing_user_id")
                ],
                recovery_hint="Authenticated user id is required.",
            ),
            http_status=401,
        )

    user_hash = _hash_user_id(uid)
    stages: list[StageResult] = []

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_lock(%s)", (_OPERATION_LOCK_KEY,))
            try:
                operation = _load_or_create_operation(cur, user_hash=user_hash, user_id=uid)
                if operation.status == OperationStatus.COMPLETED.value:
                    stages = _stage_results_from_operation(operation)
                    return AccountDeletionOutcome(
                        completed=True,
                        operation_id=operation.operation_id,
                        stages=stages,
                    )

                _mark_operation_in_progress(cur, operation.operation_id)
                conn.commit()
                auth_provider = _resolve_auth_provider(cur, operation, uid)
                conn.commit()

                try:
                    _validate_runtime_configuration(auth_provider)
                except (SupabaseAdminConfigError, AppleSignInConfigError) as exc:
                    _fail_operation(cur, operation.operation_id, str(exc))
                    operation = _reload_operation(cur, operation.operation_id)
                    outcome = AccountDeletionOutcome(
                        completed=False,
                        operation_id=operation.operation_id,
                        stages=_stage_results_from_operation(operation),
                        recovery_hint=str(exc),
                    )
                    _raise_deletion_error(conn, outcome, http_status=503, cause=exc)

                operation = _reload_operation(cur, operation.operation_id)

                if auth_provider == "apple":
                    operation = _run_apple_revoke_stage(
                        cur,
                        operation,
                        user_id=uid,
                        apple_authorization_code=apple_authorization_code,
                    )
                elif operation.apple_revoke_status == StageStatus.PENDING.value:
                    operation = _set_stage_status(
                        cur,
                        operation,
                        stage_column="apple_revoke_status",
                        stage_name=DeletionStage.APPLE_REVOKE.value,
                        status=StageStatus.NOT_APPLICABLE.value,
                        detail="non_apple_provider",
                    )
                conn.commit()

                if operation.apple_revoke_status == StageStatus.FAILED.value:
                    outcome = _operation_outcome(operation, completed=False)
                    _raise_deletion_error(conn, outcome, http_status=422)

                if operation.public_data_status in {
                    StageStatus.PENDING.value,
                    StageStatus.FAILED.value,
                }:
                    operation = _run_public_data_stage(cur, operation, uid)
                conn.commit()

                if operation.public_data_status == StageStatus.FAILED.value:
                    outcome = _operation_outcome(operation, completed=False)
                    _raise_deletion_error(conn, outcome, http_status=503)

                if uses_supabase_auth():
                    if operation.supabase_auth_status in {
                        StageStatus.PENDING.value,
                        StageStatus.FAILED.value,
                    }:
                        operation = _run_supabase_auth_stage(cur, operation, uid)
                elif operation.supabase_auth_status == StageStatus.PENDING.value:
                    operation = _set_stage_status(
                        cur,
                        operation,
                        stage_column="supabase_auth_status",
                        stage_name=DeletionStage.SUPABASE_AUTH.value,
                        status=StageStatus.NOT_APPLICABLE.value,
                        detail="legacy_auth_mode",
                    )
                conn.commit()

                completed = _operation_is_complete(operation)
                if completed:
                    _complete_operation(cur, operation.operation_id)
                elif operation.supabase_auth_status == StageStatus.FAILED.value:
                    _fail_operation(cur, operation.operation_id, "supabase_auth_failed")
                conn.commit()

                outcome = _operation_outcome(operation, completed=completed)
                if not completed:
                    _raise_deletion_error(
                        conn,
                        outcome,
                        http_status=_http_status_for_operation(operation),
                    )
                return outcome
            finally:
                cur.execute("SELECT pg_advisory_unlock(%s)", (_OPERATION_LOCK_KEY,))


def _hash_user_id(user_id: str) -> str:
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()


def _raise_deletion_error(
    conn,
    outcome: AccountDeletionOutcome,
    *,
    http_status: int,
    cause: BaseException | None = None,
) -> None:
    conn.commit()
    if cause is not None:
        raise AccountDeletionError(outcome, http_status=http_status) from cause
    raise AccountDeletionError(outcome, http_status=http_status)


def _validate_runtime_configuration(auth_provider: str) -> None:
    if uses_supabase_auth():
        require_supabase_admin_config()
    if auth_provider == "apple":
        require_apple_sign_in_config()


def _is_confirmed_provider(provider: str) -> bool:
    return provider.strip().lower() in _CONFIRMED_AUTH_PROVIDERS


def _resolve_auth_provider(
    cur,
    operation: _OperationRow,
    user_id: str,
    *,
    allow_unconfirmed: bool = False,
) -> str:
    stored = operation.auth_provider.strip().lower()
    if _is_confirmed_provider(stored):
        return stored

    detected = detect_auth_provider(user_id).strip().lower()
    if not _is_confirmed_provider(detected):
        if allow_unconfirmed:
            return _UNCONFIRMED_AUTH_PROVIDER
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                operation_id=operation.operation_id,
                stages=_stage_results_from_operation(operation),
                recovery_hint=(
                    "Unable to determine account auth provider. "
                    "Retry after authentication service configuration is restored."
                ),
            ),
            http_status=503,
        )

    if stored == "apple" and detected != "apple":
        raise AccountDeletionError(
            AccountDeletionOutcome(
                completed=False,
                operation_id=operation.operation_id,
                stages=_stage_results_from_operation(operation),
                recovery_hint="Apple-linked accounts cannot be downgraded to a non-Apple provider.",
            ),
            http_status=409,
        )

    if stored != detected:
        _update_operation_provider(cur, operation.operation_id, detected)
        operation = _reload_operation(cur, operation.operation_id)
    return detected


def _load_or_create_operation(cur, *, user_hash: str, user_id: str) -> _OperationRow:
    cur.execute(
        """
        SELECT operation_id::text, user_id_hash, auth_provider, status,
               apple_revoke_status, public_data_status, supabase_auth_status
        FROM account_deletion_operations
        WHERE user_id_hash = %s
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (user_hash,),
    )
    row = cur.fetchone()
    if row:
        operation = _operation_from_row(row)
        if operation.status == OperationStatus.COMPLETED.value:
            return operation
        if operation.status in {
            OperationStatus.PENDING.value,
            OperationStatus.IN_PROGRESS.value,
            OperationStatus.FAILED.value,
        }:
            return operation

    operation_id = str(uuid.uuid4())
    auth_provider = detect_auth_provider(user_id)
    cur.execute(
        """
        INSERT INTO account_deletion_operations (
            operation_id, user_id_hash, auth_provider, status
        ) VALUES (%s::uuid, %s, %s, %s)
        """,
        (operation_id, user_hash, auth_provider, OperationStatus.PENDING.value),
    )
    _record_stage_event(
        cur,
        operation_id=operation_id,
        stage="operation",
        status=OperationStatus.PENDING.value,
        detail="created",
    )
    return _reload_operation(cur, operation_id)


def _reload_operation(cur, operation_id: str) -> _OperationRow:
    cur.execute(
        """
        SELECT operation_id::text, user_id_hash, auth_provider, status,
               apple_revoke_status, public_data_status, supabase_auth_status
        FROM account_deletion_operations
        WHERE operation_id = %s::uuid
        """,
        (operation_id,),
    )
    row = cur.fetchone()
    if not row:
        raise RuntimeError("account deletion operation missing after create")
    return _operation_from_row(row)


def _coerce_text(value: Any) -> str:
    if isinstance(value, bytes):
        return value.decode("utf-8")
    return str(value)


def _operation_from_row(row: dict[str, Any]) -> _OperationRow:
    return _OperationRow(
        operation_id=_coerce_text(row["operation_id"]),
        user_id_hash=_coerce_text(row["user_id_hash"]),
        auth_provider=_coerce_text(row["auth_provider"]),
        status=_coerce_text(row["status"]),
        apple_revoke_status=_coerce_text(row["apple_revoke_status"]),
        public_data_status=_coerce_text(row["public_data_status"]),
        supabase_auth_status=_coerce_text(row["supabase_auth_status"]),
    )


def _mark_operation_in_progress(cur, operation_id: str) -> None:
    cur.execute(
        """
        UPDATE account_deletion_operations
        SET status = %s,
            attempt_count = attempt_count + 1,
            updated_at = NOW()
        WHERE operation_id = %s::uuid
        """,
        (OperationStatus.IN_PROGRESS.value, operation_id),
    )


def _update_operation_provider(cur, operation_id: str, auth_provider: str) -> None:
    cur.execute(
        """
        UPDATE account_deletion_operations
        SET auth_provider = %s, updated_at = NOW()
        WHERE operation_id = %s::uuid
        """,
        (auth_provider, operation_id),
    )


def _set_stage_status(
    cur,
    operation: _OperationRow,
    *,
    stage_column: str,
    stage_name: str,
    status: str,
    detail: str | None = None,
) -> _OperationRow:
    cur.execute(
        f"""
        UPDATE account_deletion_operations
        SET {stage_column} = %s,
            updated_at = NOW(),
            last_error = CASE WHEN %s = 'failed' THEN %s ELSE last_error END
        WHERE operation_id = %s::uuid
        """,
        (status, status, detail, operation.operation_id),
    )
    _record_stage_event(
        cur,
        operation_id=operation.operation_id,
        stage=stage_name,
        status=status,
        detail=detail,
    )
    return _reload_operation(cur, operation.operation_id)


def _record_stage_event(
    cur,
    *,
    operation_id: str,
    stage: str,
    status: str,
    detail: str | None,
) -> None:
    cur.execute(
        """
        INSERT INTO account_deletion_stage_events (operation_id, stage, status, detail)
        VALUES (%s::uuid, %s, %s, %s)
        """,
        (operation_id, stage, status, detail),
    )


def _run_apple_revoke_stage(
    cur,
    operation: _OperationRow,
    *,
    user_id: str,
    apple_authorization_code: str | None,
) -> _OperationRow:
    if operation.apple_revoke_status == StageStatus.COMPLETED.value:
        return operation
    code = (apple_authorization_code or "").strip()
    if not code:
        return _set_stage_status(
            cur,
            operation,
            stage_column="apple_revoke_status",
            stage_name=DeletionStage.APPLE_REVOKE.value,
            status=StageStatus.FAILED.value,
            detail="missing_authorization_code",
        )
    try:
        _revoke_apple_token(code, expected_user_id=user_id)
    except AppleSignInConfigError as exc:
        return _set_stage_status(
            cur,
            operation,
            stage_column="apple_revoke_status",
            stage_name=DeletionStage.APPLE_REVOKE.value,
            status=StageStatus.FAILED.value,
            detail=str(exc),
        )
    except httpx.HTTPError:
        logger.exception("account_deletion_apple_revoke_failed")
        return _set_stage_status(
            cur,
            operation,
            stage_column="apple_revoke_status",
            stage_name=DeletionStage.APPLE_REVOKE.value,
            status=StageStatus.FAILED.value,
            detail="network_error",
        )

    return _set_stage_status(
        cur,
        operation,
        stage_column="apple_revoke_status",
        stage_name=DeletionStage.APPLE_REVOKE.value,
        status=StageStatus.COMPLETED.value,
    )


def _run_public_data_stage(cur, operation: _OperationRow, user_id: str) -> _OperationRow:
    try:
        deleted = privacy_repository.delete_user_data(user_id=user_id)
    except PsycopgError:
        logger.exception("account_deletion_public_data_failed user_present=1")
        return _set_stage_status(
            cur,
            operation,
            stage_column="public_data_status",
            stage_name=DeletionStage.PUBLIC_DATA.value,
            status=StageStatus.FAILED.value,
            detail="database_error",
        )
    except Exception:
        logger.exception("account_deletion_public_data_failed")
        return _set_stage_status(
            cur,
            operation,
            stage_column="public_data_status",
            stage_name=DeletionStage.PUBLIC_DATA.value,
            status=StageStatus.FAILED.value,
            detail="unexpected_error",
        )

    status = StageStatus.COMPLETED.value if deleted else StageStatus.NOT_APPLICABLE.value
    detail = None if deleted else "already_deleted"
    return _set_stage_status(
        cur,
        operation,
        stage_column="public_data_status",
        stage_name=DeletionStage.PUBLIC_DATA.value,
        status=status,
        detail=detail,
    )


def _run_supabase_auth_stage(cur, operation: _OperationRow, user_id: str) -> _OperationRow:
    try:
        deleted = delete_auth_user(user_id)
    except SupabaseAdminConfigError as exc:
        return _set_stage_status(
            cur,
            operation,
            stage_column="supabase_auth_status",
            stage_name=DeletionStage.SUPABASE_AUTH.value,
            status=StageStatus.FAILED.value,
            detail=str(exc),
        )
    except httpx.HTTPError:
        logger.exception("account_deletion_supabase_auth_failed")
        return _set_stage_status(
            cur,
            operation,
            stage_column="supabase_auth_status",
            stage_name=DeletionStage.SUPABASE_AUTH.value,
            status=StageStatus.FAILED.value,
            detail="network_error",
        )
    except Exception:
        logger.exception("account_deletion_supabase_auth_failed")
        return _set_stage_status(
            cur,
            operation,
            stage_column="supabase_auth_status",
            stage_name=DeletionStage.SUPABASE_AUTH.value,
            status=StageStatus.FAILED.value,
            detail="unexpected_error",
        )

    status = StageStatus.COMPLETED.value if deleted else StageStatus.NOT_APPLICABLE.value
    detail = None if deleted else "already_deleted"
    return _set_stage_status(
        cur,
        operation,
        stage_column="supabase_auth_status",
        stage_name=DeletionStage.SUPABASE_AUTH.value,
        status=status,
        detail=detail,
    )


def _revoke_apple_token(authorization_code: str, *, expected_user_id: str) -> None:
    team_id = settings.apple_team_id.strip()
    key_id = settings.apple_sign_in_key_id.strip()
    services_id = settings.apple_services_id.strip() or "com.hiair.app.auth"
    if not team_id or not key_id:
        raise AppleSignInConfigError(
            "APPLE_TEAM_ID and APPLE_SIGN_IN_KEY_ID are required for Apple token revocation."
        )

    with temporary_apple_p8_path() as p8_path:
        client_secret = _build_apple_client_secret(
            team_id=team_id,
            key_id=key_id,
            services_id=services_id,
            p8_path=p8_path,
        )
        for attempt in range(1, _MAX_HTTP_RETRIES + 1):
            with httpx.Client(timeout=_HTTP_TIMEOUT_SECONDS) as client:
                token_response = client.post(
                    "https://appleid.apple.com/auth/token",
                    data={
                        "grant_type": "authorization_code",
                        "code": authorization_code,
                        "client_id": services_id,
                        "client_secret": client_secret,
                    },
                )
                if token_response.status_code != 200:
                    if attempt >= _MAX_HTTP_RETRIES:
                        raise httpx.HTTPStatusError(
                            "apple token exchange failed",
                            request=token_response.request,
                            response=token_response,
                        )
                    time.sleep(attempt)
                    continue
                payload = token_response.json()
                id_token = str(payload.get("id_token") or "").strip()
                if not id_token:
                    raise AppleSignInConfigError("Apple token exchange returned no id_token.")
                apple_sub = _decode_apple_id_token_sub(id_token)
                if not _apple_identity_matches(expected_user_id, apple_sub):
                    raise AppleSignInConfigError(
                        "Apple authorization does not match the authenticated account."
                    )
                token = str(payload.get("refresh_token") or payload.get("access_token") or "").strip()
                hint = "refresh_token" if payload.get("refresh_token") else "access_token"
                if not token:
                    raise AppleSignInConfigError("Apple token exchange returned no revocable token.")
                revoke = client.post(
                    "https://appleid.apple.com/auth/revoke",
                    data={
                        "client_id": services_id,
                        "client_secret": client_secret,
                        "token": token,
                        "token_type_hint": hint,
                    },
                )
                if revoke.status_code in (200, 204):
                    return
                if attempt >= _MAX_HTTP_RETRIES:
                    raise httpx.HTTPStatusError(
                        "apple token revoke failed",
                        request=revoke.request,
                        response=revoke,
                    )
                time.sleep(attempt)


def _build_apple_client_secret(
    *,
    team_id: str,
    key_id: str,
    services_id: str,
    p8_path: Any,
) -> str:
    now = int(time.time())
    payload = {
        "iss": team_id,
        "iat": now,
        "exp": now + 3600,
        "aud": "https://appleid.apple.com",
        "sub": services_id,
    }
    return jwt.encode(
        payload,
        p8_path.read_text(encoding="utf-8"),
        algorithm="ES256",
        headers={"kid": key_id},
    )


def _decode_apple_id_token_sub(id_token: str) -> str:
    try:
        claims = jwt.decode(id_token, options={"verify_signature": False})
    except jwt.PyJWTError as exc:
        raise AppleSignInConfigError("Apple id_token could not be decoded.") from exc
    sub = str(claims.get("sub") or "").strip()
    if not sub:
        raise AppleSignInConfigError("Apple id_token is missing sub.")
    return sub


def _apple_identity_matches(user_id: str, apple_sub: str) -> bool:
    user = fetch_auth_user(user_id)
    if not user:
        return False
    identities = user.get("identities")
    if not isinstance(identities, list):
        return False
    for identity in identities:
        if not isinstance(identity, dict):
            continue
        if str(identity.get("provider") or "").strip().lower() != "apple":
            continue
        identity_id = str(identity.get("identity_id") or "").strip()
        identity_data = identity.get("identity_data")
        data_sub = ""
        if isinstance(identity_data, dict):
            data_sub = str(identity_data.get("sub") or "").strip()
        if apple_sub and apple_sub in {identity_id, data_sub}:
            return True
    return False


def _complete_operation(cur, operation_id: str) -> None:
    cur.execute(
        """
        UPDATE account_deletion_operations
        SET status = %s,
            completed_at = NOW(),
            updated_at = NOW(),
            last_error = NULL
        WHERE operation_id = %s::uuid
        """,
        (OperationStatus.COMPLETED.value, operation_id),
    )
    _record_stage_event(
        cur,
        operation_id=operation_id,
        stage="operation",
        status=OperationStatus.COMPLETED.value,
        detail=None,
    )


def _fail_operation(cur, operation_id: str, error: str) -> None:
    cur.execute(
        """
        UPDATE account_deletion_operations
        SET status = %s,
            last_error = %s,
            updated_at = NOW()
        WHERE operation_id = %s::uuid
        """,
        (OperationStatus.FAILED.value, error, operation_id),
    )


def _operation_is_complete(operation: _OperationRow) -> bool:
    stage_values = (
        operation.apple_revoke_status,
        operation.public_data_status,
        operation.supabase_auth_status,
    )
    if any(status == StageStatus.FAILED.value for status in stage_values):
        return False
    if any(status == StageStatus.PENDING.value for status in stage_values):
        return False
    return all(
        status in {StageStatus.COMPLETED.value, StageStatus.NOT_APPLICABLE.value}
        for status in stage_values
    )


def _stage_results_from_operation(operation: _OperationRow) -> list[StageResult]:
    return [
        StageResult(DeletionStage.APPLE_REVOKE, StageStatus(operation.apple_revoke_status)),
        StageResult(DeletionStage.PUBLIC_DATA, StageStatus(operation.public_data_status)),
        StageResult(DeletionStage.SUPABASE_AUTH, StageStatus(operation.supabase_auth_status)),
    ]


def _operation_outcome(operation: _OperationRow, *, completed: bool) -> AccountDeletionOutcome:
    stages = _stage_results_from_operation(operation)
    return AccountDeletionOutcome(
        completed=completed,
        operation_id=operation.operation_id,
        stages=stages,
        recovery_hint=_recovery_hint(stages, completed),
    )


def _recovery_hint(stages: list[StageResult], completed: bool) -> str | None:
    if completed:
        return None
    failed = [stage for stage in stages if stage.status == StageStatus.FAILED]
    if not failed:
        return "Account deletion incomplete; retry while authenticated."
    details = ", ".join(f"{stage.stage.value}:{stage.detail or stage.status.value}" for stage in failed)
    return (
        "Account deletion incomplete. Retry while still authenticated for Apple revoke, "
        f"then complete remaining stages. Failed: {details}."
    )


def _http_status_for_operation(operation: _OperationRow) -> int:
    if operation.apple_revoke_status == StageStatus.FAILED.value:
        return 422
    if operation.public_data_status == StageStatus.FAILED.value:
        return 503
    if operation.supabase_auth_status == StageStatus.FAILED.value:
        return 503
    return 503
