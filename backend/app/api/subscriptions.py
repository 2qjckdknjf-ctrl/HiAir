from fastapi import APIRouter, Depends, Header, HTTPException, Request
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id
from app.core.settings import settings
from app.models.subscription import (
    ActivateSubscriptionRequest,
    SubscriptionPlan,
    SubscriptionStatusResponse,
    SubscriptionWebhookAck,
)
import app.services.subscription_provider as subscription_provider
import app.services.subscription_repository as subscription_repository

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


@router.get("/plans", response_model=list[SubscriptionPlan])
def get_plans() -> list[SubscriptionPlan]:
    return subscription_repository.list_plans()


@router.get("/me", response_model=SubscriptionStatusResponse)
def get_my_subscription(
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    try:
        return subscription_repository.get_user_subscription(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/activate", response_model=SubscriptionStatusResponse)
def activate_subscription(
    payload: ActivateSubscriptionRequest,
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    try:
        return subscription_repository.activate_subscription(
            user_id=user_id,
            plan_id=payload.plan_id,
            use_trial=payload.use_trial,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/cancel", response_model=SubscriptionStatusResponse)
def cancel_subscription(
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    try:
        return subscription_repository.cancel_subscription(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/webhook/{provider}", response_model=SubscriptionWebhookAck)
async def subscription_webhook(
    provider: str,
    request: Request,
    x_webhook_signature: str | None = Header(default=None),
) -> SubscriptionWebhookAck:
    if provider != settings.subscription_provider:
        raise HTTPException(status_code=400, detail="Provider is not enabled")
    if not settings.subscription_webhook_secret:
        raise HTTPException(status_code=503, detail="Webhook secret is not configured")

    raw_body = await request.body()
    if not subscription_provider.verify_webhook_signature(
        raw_body=raw_body,
        signature=x_webhook_signature,
        secret=settings.subscription_webhook_secret,
    ):
        raise HTTPException(status_code=401, detail="Invalid webhook signature")

    try:
        payload = await request.json()
        event = subscription_provider.parse_webhook_event(provider=provider, payload=payload)
        inserted = subscription_repository.record_webhook_event(provider=provider, event=event)
        if inserted:
            subscription_repository.apply_provider_webhook_event(event)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return SubscriptionWebhookAck(event_id=event.event_id, duplicate=not inserted)
