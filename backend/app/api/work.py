"""HiAir 2.0 Work / B2B occupational heat safety API (additive)."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.deps import get_current_user_id
from app.models.work_safety import SiteRiskResponse, WorkloadCategory, WorkSafetyEnvironmentInput
import app.services.air_environment_service as air_environment_service
import app.services.work_safety_engine as work_safety_engine

router = APIRouter(prefix="/work", tags=["work"])


def _environment_for_site(lat: float, lon: float) -> tuple[WorkSafetyEnvironmentInput, str | None]:
    """Load environment; map consumer heat index only — never infer WBGT."""
    try:
        snapshot = air_environment_service.resolve_environment_snapshot(lat=lat, lon=lon)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    feels_like = snapshot.feels_like if snapshot.feels_like is not None else snapshot.temperature_c
    wbgt_c = getattr(snapshot, "wbgt_c", None)

    return (
        WorkSafetyEnvironmentInput(
            lat=lat,
            lon=lon,
            wbgt_c=wbgt_c,
            heat_index_c=feels_like,
        ),
        snapshot.source,
    )


@router.get("/site-risk", response_model=SiteRiskResponse)
def get_site_risk(
    lat: float = Query(ge=-90, le=90),
    lon: float = Query(ge=-180, le=180),
    workload: WorkloadCategory = Query(default=WorkloadCategory.MODERATE),
    acclimatized: bool = Query(default=True),
    _user_id: str = Depends(get_current_user_id),
) -> SiteRiskResponse:
    env, source = _environment_for_site(lat, lon)
    assessment = work_safety_engine.assess_site_risk(
        env,
        workload,
        acclimatized=acclimatized,
    )
    return SiteRiskResponse(
        assessedAt=datetime.now(timezone.utc).isoformat(),
        environmentalSource=source,
        assessment=assessment,
    )
