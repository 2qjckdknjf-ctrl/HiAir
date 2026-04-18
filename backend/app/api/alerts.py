from fastapi import APIRouter, Depends, HTTPException
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.models.air import AlertEvaluateRequest, AlertEvaluateResponse
import app.services.air_repository as air_repository
import app.services.alert_orchestrator as alert_orchestrator
import app.services.notification_dispatcher as notification_dispatcher
import app.services.notification_repository as notification_repository
import app.services.settings_repository as settings_repository

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.post("/evaluate", response_model=AlertEvaluateResponse)
def evaluate_alert(
    payload: AlertEvaluateRequest,
    user_id: str = Depends(get_current_user_id),
) -> AlertEvaluateResponse:
    try:
        profile = air_repository.get_profile_context(payload.profileId)
        if profile is None:
            raise HTTPException(status_code=404, detail="Profile not found")
        if profile.user_id != user_id:
            raise HTTPException(status_code=403, detail="Profile does not belong to user")

        user_settings = settings_repository.get_user_settings(user_id)
        decision = alert_orchestrator.evaluate_alert(
            profile,
            payload.risk,
            payload.recommendation,
            language=user_settings.preferred_language,
        )
        dispatched_to_tokens = 0
        skipped = True
        dispatch_reason = "not_dispatched"
        if decision.shouldSend and decision.alertType and decision.severity:
            air_repository.save_alert_event(
                profile_id=profile.profile_id,
                alert_type=decision.alertType.value,
                severity=decision.severity.value,
                title=decision.title,
                body=decision.body,
                dedupe_key=decision.dedupeKey,
                delivery_status="queued",
            )
            targets = notification_repository.list_active_device_targets(user_id=profile.user_id)
            dispatched_to_tokens, skipped, dispatch_reason, _, _ = notification_dispatcher.dispatch_stub(
                user_id=profile.user_id,
                profile_id=profile.profile_id,
                risk_level=payload.risk.overallRisk.value,
                message=decision.body,
                device_targets=targets,
                force_send=False,
            )
        return AlertEvaluateResponse(
            profileId=profile.profile_id,
            decision=decision,
            dispatchedToTokens=dispatched_to_tokens,
            skipped=skipped,
            dispatchReason=dispatch_reason,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
