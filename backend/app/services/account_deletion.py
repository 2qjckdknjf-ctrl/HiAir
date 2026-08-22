"""Fail-closed account deletion orchestration for App Store Guideline 5.1.1(v)."""

from __future__ import annotations

import hashlib
import json
import logging
import time
from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path
from typing import Any

import httpx
import jwt
from psycopg import Error as PsycopgError

from app.core.settings import settings
from app.services.db import get_connection
import app.services.privacy_repository as privacy_repository

logger = logging.getLogger(__name__)

_BACKEND_ROOT = Path(__file__).resolve().parents[2]
_DEFAULT_APPLE_P8 = _BACKEND_ROOT / ".secrets" / "AuthKey_8BXW8SG2B4.p8"
_HTTP_TIMEOUT_SECONDS = 20.0
_MAX_HTTP_RETRIES = 2


class DeletionStage(StrEnum):
    PUBLIC_DATA = "public_data"
    SUPABASE_AUTH = "supabase_auth"
    APPLE_REVOKE = "apple_revoke"


class StageStatus(StrEnum):
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"
    NOT_APPLICABLE = "not_applicable"


@dataclass(frozen=True)
class StageResult:
    stage: DeletionStage
    status: StageStatus
    detail: str | None = None


@dataclass
class AccountDeletionOutcome:
    completed: bool
    stages: list[StageResult] = field(default_factory=list)
    recovery_hint: str | None = None

    def stage_map(self) -> dict[str, str]:
        return {result.stage.value: result.status.value for result in self.stages}


class AccountDeletionError(Exception):
    def __init__(self, outcome: AccountDeletionOutcome, http_status: int) -> None:
        super().__init__(outcome.recovery_hint or "account deletion failed")
        self.outcome = outcome
        self.http_status = http_status


def delete_account(
    *,
    user_id: str,
    apple_authorization_code: str | None = None,
    require_apple_revoke: bool = False,
) -> AccountDeletionOutcome:
    """Delete all user-owned data and auth identity with explicit stage outcomes."""
    uid = (user_id or "").strip()
    if not uid:
        outcome = AccountDeletionOutcome(
            completed=False,
            stages=[
                StageResult(
                    stage=DeletionStage.PUBLIC_DATA,
                    status=StageStatus.FAILED,
                    detail="missing_user_id",
                )
            ],
            recovery_hint="Authenticated user id is required.",
        )
        raise AccountDeletionError(outcome, http_status=401)

    stages: list[StageResult] = []
    public_deleted = _delete_public_data(uid, stages)
    auth_deleted = _delete_supabase_auth_user(uid, stages)
    apple_revoked = _revoke_apple_token_if_needed(
        apple_authorization_code,
        require_apple_revoke=require_apple_revoke,
        stages=stages,
    )

    completed = _evaluate_completion(
        public_deleted=public_deleted,
        auth_deleted=auth_deleted,
        apple_revoked=apple_revoked,
        stages=stages,
        require_apple_revoke=require_apple_revoke,
    )
    outcome = AccountDeletionOutcome(
        completed=completed,
        stages=stages,
        recovery_hint=_recovery_hint(stages, completed),
    )
    _persist_audit(uid, outcome)
    if not completed:
        raise AccountDeletionError(outcome, http_status=_failure_status(stages, public_deleted, auth_deleted))
    return outcome


def _delete_public_data(user_id: str, stages: list[StageResult]) -> bool:
    try:
        deleted = privacy_repository.delete_user_data(user_id=user_id)
    except PsycopgError:
        logger.exception("account_deletion_public_data_failed user_present=1")
        stages.append(
            StageResult(
                stage=DeletionStage.PUBLIC_DATA,
                status=StageStatus.FAILED,
                detail="database_error",
            )
        )
        return False

    status = StageStatus.COMPLETED if deleted else StageStatus.NOT_APPLICABLE
    stages.append(
        StageResult(
            stage=DeletionStage.PUBLIC_DATA,
            status=status,
            detail=None if deleted else "already_deleted",
        )
    )
    return deleted


def _delete_supabase_auth_user(user_id: str, stages: list[StageResult]) -> bool:
    if not _supabase_admin_configured():
        stages.append(
            StageResult(
                stage=DeletionStage.SUPABASE_AUTH,
                status=StageStatus.SKIPPED,
                detail="not_configured",
            )
        )
        return True

    headers = {
        "apikey": settings.supabase_service_role_key.strip(),
        "Authorization": f"Bearer {settings.supabase_service_role_key.strip()}",
    }
    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/admin/users/{user_id}"
    for attempt in range(1, _MAX_HTTP_RETRIES + 1):
        try:
            with httpx.Client(timeout=_HTTP_TIMEOUT_SECONDS) as client:
                response = client.delete(url, headers=headers)
        except httpx.HTTPError:
            logger.exception("account_deletion_supabase_auth_failed attempt=%s", attempt)
            if attempt >= _MAX_HTTP_RETRIES:
                stages.append(
                    StageResult(
                        stage=DeletionStage.SUPABASE_AUTH,
                        status=StageStatus.FAILED,
                        detail="network_error",
                    )
                )
                return False
            time.sleep(attempt)
            continue

        if response.status_code in (200, 204):
            stages.append(
                StageResult(
                    stage=DeletionStage.SUPABASE_AUTH,
                    status=StageStatus.COMPLETED,
                )
            )
            return True
        if response.status_code == 404:
            stages.append(
                StageResult(
                    stage=DeletionStage.SUPABASE_AUTH,
                    status=StageStatus.NOT_APPLICABLE,
                    detail="already_deleted",
                )
            )
            return True

        logger.info(
            "account_deletion_supabase_auth_failed status=%s attempt=%s",
            response.status_code,
            attempt,
        )
        if attempt >= _MAX_HTTP_RETRIES:
            stages.append(
                StageResult(
                    stage=DeletionStage.SUPABASE_AUTH,
                    status=StageStatus.FAILED,
                    detail=f"http_{response.status_code}",
                )
            )
            return False
        time.sleep(attempt)
    return False


def _revoke_apple_token_if_needed(
    authorization_code: str | None,
    *,
    require_apple_revoke: bool,
    stages: list[StageResult],
) -> bool:
    code = (authorization_code or "").strip()
    if not code:
        if require_apple_revoke:
            stages.append(
                StageResult(
                    stage=DeletionStage.APPLE_REVOKE,
                    status=StageStatus.FAILED,
                    detail="missing_authorization_code",
                )
            )
            return False
        stages.append(
            StageResult(
                stage=DeletionStage.APPLE_REVOKE,
                status=StageStatus.NOT_APPLICABLE,
                detail="no_code_provided",
            )
        )
        return True

    client_secret = _apple_client_secret()
    if not client_secret:
        stages.append(
            StageResult(
                stage=DeletionStage.APPLE_REVOKE,
                status=StageStatus.FAILED,
                detail="missing_client_secret",
            )
        )
        return False

    client_id = settings.apple_services_id.strip() or "com.hiair.app.auth"
    for attempt in range(1, _MAX_HTTP_RETRIES + 1):
        try:
            with httpx.Client(timeout=_HTTP_TIMEOUT_SECONDS) as client:
                token_response = client.post(
                    "https://appleid.apple.com/auth/token",
                    data={
                        "grant_type": "authorization_code",
                        "code": code,
                        "client_id": client_id,
                        "client_secret": client_secret,
                    },
                )
                if token_response.status_code != 200:
                    logger.info(
                        "account_deletion_apple_exchange_failed status=%s attempt=%s",
                        token_response.status_code,
                        attempt,
                    )
                    if attempt >= _MAX_HTTP_RETRIES:
                        stages.append(
                            StageResult(
                                stage=DeletionStage.APPLE_REVOKE,
                                status=StageStatus.FAILED,
                                detail=f"exchange_http_{token_response.status_code}",
                            )
                        )
                        return False
                    time.sleep(attempt)
                    continue

                payload = token_response.json()
                token = str(payload.get("refresh_token") or payload.get("access_token") or "").strip()
                hint = "refresh_token" if payload.get("refresh_token") else "access_token"
                if not token:
                    stages.append(
                        StageResult(
                            stage=DeletionStage.APPLE_REVOKE,
                            status=StageStatus.FAILED,
                            detail="missing_token",
                        )
                    )
                    return False

                revoke = client.post(
                    "https://appleid.apple.com/auth/revoke",
                    data={
                        "client_id": client_id,
                        "client_secret": client_secret,
                        "token": token,
                        "token_type_hint": hint,
                    },
                )
        except httpx.HTTPError:
            logger.exception("account_deletion_apple_revoke_failed attempt=%s", attempt)
            if attempt >= _MAX_HTTP_RETRIES:
                stages.append(
                    StageResult(
                        stage=DeletionStage.APPLE_REVOKE,
                        status=StageStatus.FAILED,
                        detail="network_error",
                    )
                )
                return False
            time.sleep(attempt)
            continue

        if revoke.status_code in (200, 204):
            stages.append(
                StageResult(
                    stage=DeletionStage.APPLE_REVOKE,
                    status=StageStatus.COMPLETED,
                )
            )
            return True

        logger.info(
            "account_deletion_apple_revoke_failed status=%s attempt=%s",
            revoke.status_code,
            attempt,
        )
        if attempt >= _MAX_HTTP_RETRIES:
            stages.append(
                StageResult(
                    stage=DeletionStage.APPLE_REVOKE,
                    status=StageStatus.FAILED,
                    detail=f"revoke_http_{revoke.status_code}",
                )
            )
            return False
        time.sleep(attempt)
    return False


def _evaluate_completion(
    *,
    public_deleted: bool,
    auth_deleted: bool,
    apple_revoked: bool,
    stages: list[StageResult],
    require_apple_revoke: bool,
) -> bool:
    failed = [stage for stage in stages if stage.status == StageStatus.FAILED]
    if failed:
        return False

    public_ok = public_deleted or any(
        stage.stage == DeletionStage.PUBLIC_DATA and stage.status == StageStatus.NOT_APPLICABLE
        for stage in stages
    )
    auth_ok = auth_deleted or any(
        stage.stage == DeletionStage.SUPABASE_AUTH
        and stage.status in {StageStatus.COMPLETED, StageStatus.NOT_APPLICABLE, StageStatus.SKIPPED}
        for stage in stages
    )
    apple_ok = apple_revoked or not require_apple_revoke
    return public_ok and auth_ok and apple_ok


def _failure_status(stages: list[StageResult], public_deleted: bool, auth_deleted: bool) -> int:
    if not public_deleted and not auth_deleted:
        if any(stage.status == StageStatus.NOT_APPLICABLE for stage in stages):
            return 404
        return 404
    return 503


def _recovery_hint(stages: list[StageResult], completed: bool) -> str | None:
    if completed:
        return None
    failed = [stage for stage in stages if stage.status == StageStatus.FAILED]
    if not failed:
        return "Account deletion incomplete; retry the request."
    details = ", ".join(f"{stage.stage.value}:{stage.detail or stage.status.value}" for stage in failed)
    return (
        "Account deletion incomplete. Retry after resolving failed stages. "
        f"Failed stages: {details}."
    )


def _supabase_admin_configured() -> bool:
    service = settings.supabase_service_role_key.strip()
    return bool(settings.supabase_url.strip() and service and service.startswith("eyJ"))


def _apple_client_secret() -> str:
    team_id = settings.apple_team_id.strip() or "43A4KW5BKB"
    key_id = settings.apple_sign_in_key_id.strip() or "8BXW8SG2B4"
    services_id = settings.apple_services_id.strip() or "com.hiair.app.auth"
    configured_path = settings.apple_sign_in_p8_path.strip()
    p8_path = Path(configured_path) if configured_path else _DEFAULT_APPLE_P8
    if not p8_path.is_file():
        return ""
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


def _persist_audit(user_id: str, outcome: AccountDeletionOutcome) -> None:
    user_hash = hashlib.sha256(user_id.encode("utf-8")).hexdigest()
    stage_payload: dict[str, Any] = outcome.stage_map()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                if not _public_table_exists(cur, "account_deletion_audit"):
                    return
                cur.execute(
                    """
                    INSERT INTO account_deletion_audit (
                        user_id_hash,
                        stage_status,
                        completed,
                        attempt_count
                    )
                    VALUES (%s, %s::jsonb, %s, 1)
                    ON CONFLICT (user_id_hash) DO UPDATE
                    SET last_attempt_at = NOW(),
                        stage_status = EXCLUDED.stage_status,
                        completed = EXCLUDED.completed,
                        attempt_count = account_deletion_audit.attempt_count + 1
                    """,
                    (user_hash, json.dumps(stage_payload), outcome.completed),
                )
            conn.commit()
    except PsycopgError:
        logger.exception("account_deletion_audit_persist_failed")


def _public_table_exists(cur, table_name: str) -> bool:
    cur.execute(
        """
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = %s
        )
        """,
        (table_name,),
    )
    row = cur.fetchone()
    if not row:
        return False
    return bool(next(iter(row.values())))
