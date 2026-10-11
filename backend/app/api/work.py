"""HiAir 2.0 Work / B2B occupational heat safety API (additive)."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.deps import get_current_user_id
from app.models.work_safety import (
    SiteRiskResponse,
    WorkloadCategory,
    WorkSafetyEnvironmentInput,
    WorkSite,
    WorkSiteCreateRequest,
    WorkSiteListResponse,
    WorkSiteWbgtIngestRequest,
)
import app.services.air_environment_service as air_environment_service
import app.services.travel_repository as travel_repository
import app.services.work_safety_engine as work_safety_engine
import app.services.work_sites_repository as work_sites_repository

router = APIRouter(prefix="/work", tags=["work"])


def _environment_for_site(
    lat: float,
    lon: float,
    *,
    instrument_wbgt_c: float | None = None,
) -> tuple[WorkSafetyEnvironmentInput, str | None]:
    """Load environment; instrument WBGT wins over meteo estimate when present."""
    try:
        snapshot = air_environment_service.resolve_environment_snapshot(lat=lat, lon=lon)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    feels_like = snapshot.feels_like if snapshot.feels_like is not None else snapshot.temperature_c

    if instrument_wbgt_c is not None:
        return (
            WorkSafetyEnvironmentInput(
                lat=lat,
                lon=lon,
                wbgt_c=float(instrument_wbgt_c),
                wbgt_estimated=False,
                heat_index_c=feels_like,
            ),
            "instrument_wbgt",
        )

    wbgt_c = snapshot.wbgt_c
    wbgt_estimated = bool(snapshot.wbgt_estimated and wbgt_c is not None)
    return (
        WorkSafetyEnvironmentInput(
            lat=lat,
            lon=lon,
            wbgt_c=wbgt_c,
            wbgt_estimated=wbgt_estimated,
            heat_index_c=feels_like,
        ),
        snapshot.source,
    )


@router.get("/sites", response_model=WorkSiteListResponse)
def list_work_sites(user_id: str = Depends(get_current_user_id)) -> WorkSiteListResponse:
    return WorkSiteListResponse(sites=work_sites_repository.list_sites(user_id=user_id))


@router.post("/sites", response_model=WorkSite)
def create_work_site(
    payload: WorkSiteCreateRequest,
    user_id: str = Depends(get_current_user_id),
) -> WorkSite:
    return work_sites_repository.create_site(user_id=user_id, payload=payload)


@router.delete("/sites/{site_id}", status_code=204)
def delete_work_site(
    site_id: str,
    user_id: str = Depends(get_current_user_id),
) -> None:
    deleted = work_sites_repository.delete_site(user_id=user_id, site_id=site_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Work site not found")


@router.post("/sites/{site_id}/wbgt-readings")
def ingest_work_site_wbgt(
    site_id: str,
    payload: WorkSiteWbgtIngestRequest,
    user_id: str = Depends(get_current_user_id),
) -> dict:
    try:
        reading = work_sites_repository.ingest_wbgt(
            user_id=user_id,
            site_id=site_id,
            payload=payload,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    measured = reading["measured_at"]
    return {
        "id": reading["id"],
        "siteId": reading["site_id"],
        "wbgtC": reading["wbgt_c"],
        "measuredAt": measured.isoformat() if hasattr(measured, "isoformat") else measured,
        "source": reading["source"],
    }


@router.get("/site-risk", response_model=SiteRiskResponse)
def get_site_risk(
    lat: float | None = Query(default=None, ge=-90, le=90),
    lon: float | None = Query(default=None, ge=-180, le=180),
    siteId: str | None = Query(default=None),
    workload: WorkloadCategory = Query(default=WorkloadCategory.MODERATE),
    acclimatized: bool = Query(default=True),
    user_id: str = Depends(get_current_user_id),
) -> SiteRiskResponse:
    instrument_wbgt: float | None = None
    if siteId:
        site = work_sites_repository.get_site(user_id=user_id, site_id=siteId)
        if site is None:
            raise HTTPException(status_code=404, detail="Work site not found")
        lat, lon = site.lat, site.lon
        instrument_wbgt = work_sites_repository.latest_instrument_wbgt(
            user_id=user_id,
            site_id=siteId,
        )
    else:
        if lat is None or lon is None:
            raise HTTPException(status_code=422, detail="lat/lon or siteId is required")
        travel = travel_repository.get_travel_session(user_id)
        if travel.active and travel.lat is not None and travel.lon is not None:
            lat, lon = travel.lat, travel.lon

    env, source = _environment_for_site(lat, lon, instrument_wbgt_c=instrument_wbgt)
    assessment = work_safety_engine.assess_site_risk(
        env,
        workload,
        acclimatized=acclimatized,
    )
    if siteId:
        assessment = assessment.model_copy(update={"siteId": siteId})
    if instrument_wbgt is not None:
        codes = list(assessment.reasonCodes)
        codes = [c for c in codes if c not in {"wbgt_estimated_from_meteo", "not_instrument_wbgt"}]
        if "instrument_wbgt" not in codes:
            codes.append("instrument_wbgt")
        assessment = assessment.model_copy(update={"reasonCodes": codes})

    return SiteRiskResponse(
        assessedAt=datetime.now(timezone.utc).isoformat(),
        environmentalSource=source,
        assessment=assessment,
    )
