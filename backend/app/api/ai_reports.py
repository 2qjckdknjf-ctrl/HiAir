from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
import app.services.ai_report_service as ai_report_service
import app.services.profile_access as profile_access

router = APIRouter(prefix="/ai", tags=["ai-reports"])


@router.get("/reports/{kind}")
def get_ai_report(
    kind: str,
    profile_id: str = Query(..., alias="profile_id"),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    normalized = kind.strip().lower()
    if normalized not in {"morning", "evening", "weekly"}:
        raise HTTPException(status_code=400, detail="kind must be morning, evening, or weekly")
    if not profile_access.profile_exists(profile_id):
        raise HTTPException(status_code=404, detail="Profile not found")
    if not profile_access.profile_belongs_to_user(profile_id, user_id):
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    try:
        return ai_report_service.build_ai_report(
            user_id=user_id,
            profile_id=profile_id,
            kind=normalized,  # type: ignore[arg-type]
        )
    except HTTPException:
        raise
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Environmental data unavailable") from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
