from fastapi import APIRouter, Depends, Header, HTTPException, Request
from psycopg import Error as PsycopgError
import logging

from app.api.deps import get_current_user_id
from app.core.settings import _is_protected_env, settings
from app.models.subscription import (
    ActivateSubscriptionRequest,
    AndroidVerifyRequest,
    IosVerifyRequest,
    RestoreSubscriptionRequest,
    SubscriptionPlan,
    SubscriptionStatusResponse,
    SubscriptionWebhookAck,
)
import app.services.subscription_provider as subscription_provider
import app.services.subscription_repository as subscription_repository
import app.services.subscription_store as subscription_store

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
logger = logging.getLogger(__name__)


def _stub_dev_only(action: str) -> None:
    if settings.subscription_provider != "stub":
        raise HTTPException(
            status_code=403,
            detail=f"{action} is only available when SUBSCRIPTION_PROVIDER=stub",
        )
    if _is_protected_env(settings.app_env):
        raise HTTPException(
            status_code=403,
            detail=f"{action} is disabled in protected environments",
        )


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


@router.post("/ios/verify", response_model=SubscriptionStatusResponse)
def verify_ios_subscription(
    payload: IosVerifyRequest,
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    cfg = subscription_store._config_from_env()
    logger.info(
        "subscription_ios_verify user_id=%s product_id=%s verifier_mode=%s",
        user_id,
        payload.product_id,
        cfg.apple_mode,
    )
    try:
        purchase = subscription_store.verify_ios_purchase(
            payload.signed_transaction,
            product_id=payload.product_id,
        )
        result = subscription_repository.apply_verified_purchase(user_id=user_id, purchase=purchase)
        logger.info(
            "subscription_ios_verify_result user_id=%s status=%s is_premium=%s expires_at=%s",
            user_id,
            result.status,
            bool(getattr(result.entitlement, "is_premium", False) if result.entitlement else False),
            getattr(result, "current_period_end", None),
        )
        return result
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


def _android_billing_unavailable(exc: Exception) -> HTTPException:
    detail = getattr(exc, "args", ("Android billing is temporarily unavailable.",))
    message = detail[0] if detail else "Android billing is temporarily unavailable."
    return HTTPException(status_code=503, detail=str(message))


@router.post("/android/verify", response_model=SubscriptionStatusResponse)
def verify_android_subscription(
    payload: AndroidVerifyRequest,
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    cfg = subscription_store._config_from_env()
    logger.info(
        "subscription_android_verify user_id=%s product_id=%s verifier_mode=%s",
        user_id,
        payload.product_id,
        cfg.google_mode,
    )
    try:
        purchase = subscription_store.verify_android_purchase(
            payload.product_id,
            payload.purchase_token,
        )
        result = subscription_repository.apply_verified_purchase(user_id=user_id, purchase=purchase)
        logger.info(
            "subscription_android_verify_result user_id=%s status=%s is_premium=%s expires_at=%s",
            user_id,
            result.status,
            bool(getattr(result.entitlement, "is_premium", False) if result.entitlement else False),
            getattr(result, "current_period_end", None),
        )
        return result
    except subscription_store.GooglePlayVerifierDisabledError as exc:
        raise _android_billing_unavailable(exc) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/restore", response_model=SubscriptionStatusResponse)
def restore_subscriptions(
    payload: RestoreSubscriptionRequest,
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    latest: SubscriptionStatusResponse | None = None
    try:
        if payload.platform == "ios":
            for signed in payload.ios_signed_transactions:
                purchase = subscription_store.verify_ios_purchase(signed)
                latest = subscription_repository.apply_verified_purchase(user_id=user_id, purchase=purchase)
        elif payload.platform == "android":
            # Refuse before any token decode / entitlement write when Google billing is disabled.
            subscription_store.assert_google_play_verifier_enabled()
            for item in payload.android_purchases:
                purchase = subscription_store.verify_android_purchase(item.product_id, item.purchase_token)
                latest = subscription_repository.apply_verified_purchase(user_id=user_id, purchase=purchase)
        else:
            raise HTTPException(status_code=400, detail="Restore supports ios or android platform only")
    except subscription_store.GooglePlayVerifierDisabledError as exc:
        raise _android_billing_unavailable(exc) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    if latest is None:
        return subscription_repository.get_user_subscription(user_id=user_id)
    return latest


@router.post("/activate", response_model=SubscriptionStatusResponse)
def activate_subscription(
    payload: ActivateSubscriptionRequest,
    user_id: str = Depends(get_current_user_id),
) -> SubscriptionStatusResponse:
    _stub_dev_only("Manual activation")
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
    _stub_dev_only("Manual cancellation")
    try:
        return subscription_repository.cancel_subscription(user_id=user_id)
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc


@router.post("/webhook/apple", response_model=SubscriptionWebhookAck)
async def subscription_webhook_apple(
    request: Request,
    x_webhook_signature: str | None = Header(default=None),
) -> SubscriptionWebhookAck:
    return await _handle_provider_webhook("apple", request, x_webhook_signature)


@router.post("/webhook/google", response_model=SubscriptionWebhookAck)
async def subscription_webhook_google(
    request: Request,
    x_webhook_signature: str | None = Header(default=None, alias="X-Goog-Channel-Token"),
) -> SubscriptionWebhookAck:
    try:
        subscription_store.assert_google_play_verifier_enabled()
    except subscription_store.GooglePlayVerifierDisabledError as exc:
        raise _android_billing_unavailable(exc) from exc
    return await _handle_provider_webhook("google", request, x_webhook_signature)


@router.post("/webhook/{provider}", response_model=SubscriptionWebhookAck)
async def subscription_webhook(
    provider: str,
    request: Request,
    x_webhook_signature: str | None = Header(default=None),
) -> SubscriptionWebhookAck:
    if provider in ("apple", "google"):
        raise HTTPException(status_code=400, detail="Use /webhook/apple or /webhook/google")
    if provider != settings.subscription_provider:
        raise HTTPException(status_code=400, detail="Provider is not enabled")
    return await _handle_provider_webhook(provider, request, x_webhook_signature)


async def _handle_provider_webhook(
    provider: str,
    request: Request,
    x_webhook_signature: str | None,
) -> SubscriptionWebhookAck:
    secret = settings.subscription_webhook_secret
    if not secret:
        raise HTTPException(status_code=503, detail="Webhook secret is not configured")

    raw_body = await request.body()
    if provider in ("apple", "google"):
        if not subscription_provider.verify_webhook_signature(
            raw_body=raw_body,
            signature=x_webhook_signature,
            secret=secret,
        ):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")
    else:
        if not subscription_provider.verify_webhook_signature(
            raw_body=raw_body,
            signature=x_webhook_signature,
            secret=secret,
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
