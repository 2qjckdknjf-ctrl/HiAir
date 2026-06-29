from fastapi import APIRouter, HTTPException, Query
from fastapi import Header

from app.api.deps import get_current_auth_context
from app.models.risk import EnvironmentSnapshot
from app.services.request_rate_limiter import check_limit
import app.services.air_environment_service as air_environment_service
from app.services.environment_service import build_sample_snapshot

router = APIRouter(prefix="/environment", tags=["environment"])


@router.get("/snapshot", response_model=EnvironmentSnapshot)
def get_snapshot(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    source: str = Query(default="live", pattern="^(live|cached|sample|mock)$"),
    authorization: str | None = Header(default=None),
) -> EnvironmentSnapshot:
    try:
        if source in ("sample", "mock"):
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
        return air_environment_service.resolve_environment_snapshot(lat, lon, prefer_live=False)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Snapshot fetch failed: {exc}") from exc
