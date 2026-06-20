from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.insights import MorningBriefingResponse, PersonalPatternsResponse, RiskBreakdownResponse
from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.models.wearable import WearableMetricsLatestResponse, WearableMetricsResponse, WearableMetricsSubmitRequest
import app.services.air_repository as air_repository
import app.services.morning_briefing_service as morning_briefing_service
import app.services.personal_patterns_service as personal_patterns_service
import app.services.profile_access as profile_access
import app.services.risk_breakdown_service as risk_breakdown_service
import app.services.risk_repository as risk_repository
import app.services.settings_repository as settings_repository
import app.services.wearable_repository as wearable_repository
from app.services.environment_service import build_mock_snapshot

router = APIRouter(tags=["insights"])


def _resolve_profile(profile_id: str, user_id: str):
    profile = air_repository.get_profile_context(profile_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.user_id != user_id:
        raise HTTPException(status_code=403, detail="Profile does not belong to user")
    return profile


@router.post("/wearable/metrics", response_model=WearableMetricsResponse)
def submit_wearable_metrics(
    payload: WearableMetricsSubmitRequest,
    user_id: str = Depends(get_current_user_id),
) -> WearableMetricsResponse:
    if payload.profile_id:
        try:
            if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc
    try:
        return wearable_repository.save_metrics(user_id=user_id, payload=payload)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/wearable/metrics/latest", response_model=WearableMetricsLatestResponse)
def get_latest_wearable_metrics(
    profile_id: str | None = Query(default=None),
    user_id: str = Depends(get_current_user_id),
) -> WearableMetricsLatestResponse:
    try:
        metrics = wearable_repository.get_latest_metrics(user_id=user_id, profile_id=profile_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return WearableMetricsLatestResponse(available=metrics is not None, metrics=metrics)


@router.get("/insights/morning-briefing/public", response_model=MorningBriefingResponse)
def morning_briefing_public(
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    language: str = Query(default="ru"),
) -> MorningBriefingResponse:
    return morning_briefing_service.build_morning_briefing_guest(
        persona=persona,
        lat=lat,
        lon=lon,
        language=language,
    )


@router.get("/insights/risk-breakdown/public", response_model=RiskBreakdownResponse)
def risk_breakdown_public(
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
) -> RiskBreakdownResponse:
    try:
        persona_enum = PersonaType(persona.lower())
    except ValueError:
        persona_enum = PersonaType.ADULT
    environment = build_mock_snapshot(lat=lat, lon=lon)
    return risk_breakdown_service.build_risk_breakdown(
        profile_id=None,
        persona=persona_enum,
        symptoms=SymptomInput(),
        environment=environment,
        wearable=None,
    )


@router.get("/insights/morning-briefing", response_model=MorningBriefingResponse)
def morning_briefing(
    profile_id: str | None = Query(default=None),
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    user_id: str = Depends(get_current_user_id),
) -> MorningBriefingResponse:
    settings = settings_repository.get_user_settings(user_id)
    language = settings.preferred_language
    try:
        if profile_id:
            profile = _resolve_profile(profile_id, user_id)
            symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
            sleep_quality = risk_repository.get_latest_sleep_quality(profile_id=profile_id)
            symptoms = SymptomInput(
                cough=symptom_stats["cough_count"] > 0,
                wheeze=symptom_stats["wheeze_count"] > 0,
                headache=symptom_stats["headache_count"] > 0,
                fatigue=symptom_stats["fatigue_count"] > 0,
                sleep_quality=sleep_quality,
            )
            wearable = wearable_repository.get_latest_metrics(user_id=user_id, profile_id=profile_id)
            return morning_briefing_service.build_morning_briefing_for_profile(
                profile=profile,
                language=language,
                symptoms=symptoms,
                wearable=wearable,
            )
        return morning_briefing_service.build_morning_briefing_guest(
            persona=persona,
            lat=lat,
            lon=lon,
            language=language,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.get("/insights/risk-breakdown", response_model=RiskBreakdownResponse)
def risk_breakdown(
    profile_id: str | None = Query(default=None),
    persona: str = Query(default="adult"),
    lat: float = Query(default=41.39, ge=-90, le=90),
    lon: float = Query(default=2.17, ge=-180, le=180),
    user_id: str = Depends(get_current_user_id),
) -> RiskBreakdownResponse:
    try:
        persona_enum = PersonaType(persona.lower())
    except ValueError:
        persona_enum = PersonaType.ADULT

    environment = build_mock_snapshot(lat=lat, lon=lon)
    symptoms = SymptomInput()
    wearable = None

    if profile_id:
        try:
            _resolve_profile(profile_id, user_id)
            symptom_stats = risk_repository.get_recent_symptom_stats(profile_id=profile_id, hours=48)
            sleep_quality = risk_repository.get_latest_sleep_quality(profile_id=profile_id)
            symptoms = SymptomInput(
                cough=symptom_stats["cough_count"] > 0,
                wheeze=symptom_stats["wheeze_count"] > 0,
                headache=symptom_stats["headache_count"] > 0,
                fatigue=symptom_stats["fatigue_count"] > 0,
                sleep_quality=sleep_quality,
            )
            wearable = wearable_repository.get_latest_metrics(user_id=user_id, profile_id=profile_id)
        except PsycopgError as exc:
            raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return risk_breakdown_service.build_risk_breakdown(
        profile_id=profile_id,
        persona=persona_enum,
        symptoms=symptoms,
        environment=environment,
        wearable=wearable,
    )


@router.get("/insights/personal-patterns", response_model=PersonalPatternsResponse)
def personal_patterns(
    profile_id: str = Query(...),
    user_id: str = Depends(get_current_user_id),
) -> PersonalPatternsResponse:
    try:
        _resolve_profile(profile_id, user_id)
        return personal_patterns_service.build_personal_patterns(profile_id=profile_id, user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
