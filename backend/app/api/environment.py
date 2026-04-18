from fastapi import APIRouter, HTTPException, Query

from app.models.risk import EnvironmentSnapshot
from app.services.environment_service import build_mock_snapshot, fetch_live_snapshot

router = APIRouter(prefix="/environment", tags=["environment"])


@router.get("/snapshot", response_model=EnvironmentSnapshot)
def get_snapshot(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    source: str = Query(default="mock", pattern="^(mock|live)$"),
) -> EnvironmentSnapshot:
    try:
        if source == "live":
            return fetch_live_snapshot(lat, lon)
        return build_mock_snapshot(lat, lon)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Snapshot fetch failed: {exc}") from exc
