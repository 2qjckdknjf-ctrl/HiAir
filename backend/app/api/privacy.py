from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.privacy import (
    DeleteAccountRequest,
    DeleteAccountRequirementsResponse,
    DeleteAccountResponse,
    PrivacyExportResponse,
)
from app.services.account_deletion import AccountDeletionError
import app.services.account_deletion as account_deletion_service
import app.services.privacy_repository as privacy_repository

router = APIRouter(prefix="/privacy", tags=["privacy"])


@router.get("/delete-account/requirements", response_model=DeleteAccountRequirementsResponse)
def delete_account_requirements(user_id: str = Depends(get_current_user_id)) -> DeleteAccountRequirementsResponse:
    try:
        requirements = account_deletion_service.deletion_requirements(user_id=user_id)
    except AccountDeletionError as exc:
        raise HTTPException(
            status_code=exc.http_status,
            detail=_deletion_error_detail(exc),
        ) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return DeleteAccountRequirementsResponse(**requirements)


def _deletion_error_detail(exc: AccountDeletionError) -> dict[str, object]:
    return {
        "message": exc.outcome.recovery_hint or "Account deletion incomplete",
        "operation_id": exc.outcome.operation_id or None,
        "stages": exc.outcome.stage_map(),
        "recovery_hint": exc.outcome.recovery_hint,
    }


@router.get("/export", response_model=PrivacyExportResponse)
def export_my_data(user_id: str = Depends(get_current_user_id)) -> PrivacyExportResponse:
    try:
        exported = privacy_repository.export_user_data(user_id=user_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return PrivacyExportResponse(
        user_id=user_id,
        exported_at=datetime.now(tz=UTC),
        data=exported,
    )


@router.post("/delete-account", response_model=DeleteAccountResponse)
def delete_my_account(
    payload: DeleteAccountRequest,
    user_id: str = Depends(get_current_user_id),
) -> DeleteAccountResponse:
    if payload.confirmation != "DELETE":
        raise HTTPException(status_code=422, detail="confirmation must be exactly DELETE")

    try:
        outcome = account_deletion_service.delete_account(
            user_id=user_id,
            apple_authorization_code=payload.apple_authorization_code,
        )
    except AccountDeletionError as exc:
        raise HTTPException(
            status_code=exc.http_status,
            detail=_deletion_error_detail(exc),
        ) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return DeleteAccountResponse(
        deleted=outcome.completed,
        operation_id=outcome.operation_id or None,
        stages=outcome.stage_map(),
        recovery_hint=outcome.recovery_hint,
    )
