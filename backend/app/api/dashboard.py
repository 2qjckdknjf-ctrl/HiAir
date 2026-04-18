from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.dashboard import DashboardOverviewResponse
from app.models.risk import RiskEstimateResponse, SymptomInput
import app.services.notification_service as notification_service
import app.services.profile_access as profile_access
import app.services.recommendation_service as recommendation_service
import app.services.risk_repository as risk_repository
from app.services.environment_service import build_mock_snapshot
from app.services.risk_engine import estimate_risk

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/overview", response_model=DashboardOverviewResponse)
def dashboard_overview(
    profile_id: str | None = Query(default=None),
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    user_id: str = Depends(get_current_user_id),
) -> DashboardOverviewResponse:
    if profile_id:
        try:
            if not profile_access.profile_exists(profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
            symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
            sleep_quality = risk_repository.get_latest_sleep_quality(profile_id=profile_id)
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    else:
        symptom_stats = {
            "cough_count": 0,
            "wheeze_count": 0,
            "headache_count": 0,
            "fatigue_count": 0,
            "total_logs": 0,
        }
        sleep_quality = 3

    symptoms = SymptomInput(
        cough=symptom_stats["cough_count"] > 0,
        wheeze=symptom_stats["wheeze_count"] > 0,
        headache=symptom_stats["headache_count"] > 0,
        fatigue=symptom_stats["fatigue_count"] > 0,
        sleep_quality=sleep_quality,
    )

    environment = build_mock_snapshot(lat=lat, lon=lon)
    score, level, recommendations, components = estimate_risk(
        persona=persona,
        symptoms=symptoms,
        environment=environment,
    )
    risk = RiskEstimateResponse(
        score=score,
        level=level,
        recommendations=recommendations,
        components=components,
    )

    if profile_id:
        try:
            snapshot_id = risk_repository.save_environment_snapshot(environment)
            risk_repository.save_risk_score(profile_id=profile_id, risk=risk, snapshot_id=snapshot_id)
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc

    daily_summary, daily_actions = recommendation_service.build_daily_recommendation(
        risk_level=risk.level,
        symptom_stats=symptom_stats,
    )
    should_notify = notification_service.should_notify(risk)
    notification_text = notification_service.build_notification_text(risk)

    return DashboardOverviewResponse(
        profile_id=profile_id,
        environment=environment,
        risk_score=risk.score,
        risk_level=risk.level,
        recommendations=risk.recommendations,
        daily_summary=daily_summary,
        daily_actions=daily_actions,
        should_notify=should_notify,
        notification_text=notification_text,
    )
