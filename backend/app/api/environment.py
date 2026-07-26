from fastapi import APIRouter, HTTPException, Query
from fastapi import Header

from app.api.deps import get_current_auth_context
from app.core.settings import settings
from app.models.risk import EnvironmentSnapshot
from app.services.request_rate_limiter import check_limit
import app.services.air_environment_service as air_environment_service
from app.services.environment_service import build_sample_snapshot

router = APIRouter(prefix="/environment", tags=["environment"])


def _sample_snapshots_allowed() -> bool:
    app_env = settings.app_env.strip().lower()
    if app_env in {"production", "prod", "staging"}:
        return False
    return bool(settings.environment_allow_sample_fallback)


@router.get("/snapshot", response_model=EnvironmentSnapshot)
def get_snapshot(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    source: str = Query(default="live", pattern="^(live|cached|sample|mock)$"),
    authorization: str | None = Header(default=None),
) -> EnvironmentSnapshot:
    try:
        if source in ("sample", "mock"):
            if not _sample_snapshots_allowed():
                raise HTTPException(
                    status_code=403,
                    detail="Sample environment data is not available",
                )
            return build_sample_snapshot(lat, lon)
        if source == "live":
            user_id = get_current_auth_context(authorization=authorization).user_id
            if not check_limit(key=f"environment-live:{user_id}", limit=30, window_seconds=300):
                raise HTTPException(status_code=429, detail="Too many live snapshot requests")
            return air_environment_service.resolve_environment_snapshot(
                lat,
                lon,
                prefer_live=True,
                force_refresh=True,
            )
        snapshot = air_environment_service.resolve_environment_snapshot(
            lat, lon, prefer_live=False
        )
        if snapshot.source in ("sample", "mock") and not _sample_snapshots_allowed():
            raise HTTPException(
                status_code=503,
                detail="Environmental data unavailable",
            )
        return snapshot
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Snapshot fetch failed") from exc
