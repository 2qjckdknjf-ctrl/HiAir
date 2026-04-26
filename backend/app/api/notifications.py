from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from psycopg import Error as PsycopgError

from app.api.deps import get_current_user_id, require_ops_admin_token
from app.core.settings import settings
from app.models.notification import (
    DeviceTokenRegisterRequest,
    DeviceTokenRegisterResponse,
    NotificationCredentialHealthItem,
    NotificationCredentialsHealthResponse,
    NotificationCredentialsRotateRequest,
    NotificationCredentialsRotateResponse,
    NotificationDeliveryAttemptItem,
    NotificationDispatchRequest,
    NotificationDispatchResponse,
    NotificationSecretsRefreshResponse,
    SecretStoreHealthResponse,
    NotificationProviderHealthResponse,
    NotificationPreviewRequest,
    NotificationPreviewResponse,
)
import app.services.notification_credentials as notification_credentials
import app.services.notification_dispatcher as notification_dispatcher
from app.services.notification_providers import refresh_provider_secrets
import app.services.profile_access as profile_access
import app.services.notification_repository as notification_repository
import app.services.settings_repository as settings_repository
from app.services.localization import normalize_language
from app.services.secret_store import get_secret, secret_store_health
from app.services.notification_service import build_notification_text, should_notify

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/provider-health", response_model=NotificationProviderHealthResponse)
def provider_health(_authorized: bool = Depends(require_ops_admin_token)) -> NotificationProviderHealthResponse:
    fcm_legacy = bool(get_secret("FCM_SERVER_KEY", settings.fcm_server_key))
    fcm_v1 = bool(
        get_secret("FCM_PROJECT_ID", settings.fcm_project_id)
        and get_secret("FCM_CLIENT_EMAIL", settings.fcm_client_email)
        and get_secret("FCM_PRIVATE_KEY", settings.fcm_private_key)
    )
    apns_static = bool(
        get_secret("APNS_AUTH_TOKEN", settings.apns_auth_token)
        and get_secret("APNS_TOPIC", settings.apns_topic)
    )
    apns_jwt = bool(
        get_secret("APNS_TEAM_ID", settings.apns_team_id)
        and get_secret("APNS_KEY_ID", settings.apns_key_id)
        and get_secret("APNS_PRIVATE_KEY", settings.apns_private_key)
        and get_secret("APNS_TOPIC", settings.apns_topic)
    )
    return NotificationProviderHealthResponse(
        secret_source=settings.secret_source,
        mode=settings.notifications_provider_mode,
        fcm_legacy_configured=fcm_legacy,
        fcm_v1_configured=fcm_v1,
        apns_static_token_configured=apns_static,
        apns_jwt_configured=apns_jwt,
    )


@router.post("/secrets-refresh", response_model=NotificationSecretsRefreshResponse)
def secrets_refresh(x_admin_token: str | None = Header(default=None)) -> NotificationSecretsRefreshResponse:
    if not settings.notification_admin_token:
        raise HTTPException(status_code=503, detail="Notification admin token is not configured")
    if x_admin_token != settings.notification_admin_token:
        raise HTTPException(status_code=403, detail="Forbidden")
    refresh_provider_secrets()
    return NotificationSecretsRefreshResponse(
        refreshed=True,
        secret_source=settings.secret_source,
    )


@router.get("/secret-store-health", response_model=SecretStoreHealthResponse)
def get_secret_store_health(_authorized: bool = Depends(require_ops_admin_token)) -> SecretStoreHealthResponse:
    return SecretStoreHealthResponse(**secret_store_health())


@router.get("/credentials-health", response_model=NotificationCredentialsHealthResponse)
def credentials_health(_authorized: bool = Depends(require_ops_admin_token)) -> NotificationCredentialsHealthResponse:
    items = [
        NotificationCredentialHealthItem(**row)
        for row in notification_credentials.credentials_health()
    ]
    return NotificationCredentialsHealthResponse(
        mode=settings.notifications_provider_mode,
        policy_rotation_days=settings.notification_secret_rotation_days,
        items=items,
    )


@router.post("/credentials-rotate", response_model=NotificationCredentialsRotateResponse)
def credentials_rotate(
    payload: NotificationCredentialsRotateRequest,
    x_admin_token: str | None = Header(default=None),
) -> NotificationCredentialsRotateResponse:
    if not settings.notification_admin_token:
        raise HTTPException(status_code=503, detail="Notification admin token is not configured")
    if x_admin_token != settings.notification_admin_token:
        raise HTTPException(status_code=403, detail="Forbidden")
    provider = payload.provider.lower()
    if provider not in ("fcm_v1", "fcm_legacy", "apns_jwt", "apns_static"):
        raise HTTPException(status_code=422, detail="Unsupported provider")
    try:
        saved = notification_repository.save_secret_rotation_event(
            provider=provider,
            key_ref=payload.key_ref,
            rotated_by=payload.rotated_by,
            notes=payload.notes,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return NotificationCredentialsRotateResponse(
        id=saved["id"],
        provider=saved["provider"],
        created_at=saved["created_at"],
    )


@router.post("/preview", response_model=NotificationPreviewResponse)
def preview_notification(
    payload: NotificationPreviewRequest,
    language: Annotated[str | None, Query()] = None,
    accept_language: Annotated[str | None, Header(alias="Accept-Language")] = None,
    user_id: str = Depends(get_current_user_id),
) -> NotificationPreviewResponse:
    preferred_language = language or accept_language
    if preferred_language is None:
        try:
            preferred_language = settings_repository.get_user_settings(user_id).preferred_language
        except PsycopgError:
            preferred_language = "ru"
    normalized_language = normalize_language(preferred_language)
    send = should_notify(payload.risk)
    text = build_notification_text(payload.risk, language=normalized_language)
    event_id = None
    if payload.profile_id:
        try:
            if not profile_access.profile_exists(payload.profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
            event_id = notification_repository.save_notification_event(
                profile_id=payload.profile_id,
                risk_level=payload.risk.level,
                should_send=send,
                message=text,
            )
        except PsycopgError:
            # Preview should still work even if persistence fails.
            event_id = None
    return NotificationPreviewResponse(
        should_send=send,
        text=text,
        risk_level=payload.risk.level,
        event_id=event_id,
    )


@router.post("/device-token", response_model=DeviceTokenRegisterResponse)
def register_device_token(
    payload: DeviceTokenRegisterRequest,
    user_id: str = Depends(get_current_user_id),
) -> DeviceTokenRegisterResponse:
    platform = payload.platform.lower()
    if platform not in ("ios", "android"):
        raise HTTPException(status_code=422, detail="platform must be ios or android")

    try:
        if payload.profile_id:
            if not profile_access.profile_exists(payload.profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(payload.profile_id, user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
        saved = notification_repository.upsert_device_token(
            user_id=user_id,
            profile_id=payload.profile_id,
            platform=platform,
            device_token=payload.device_token,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return DeviceTokenRegisterResponse(
        id=str(saved["id"]),
        user_id=str(saved["user_id"]),
        profile_id=saved["profile_id"],
        platform=str(saved["platform"]),
        device_token=str(saved["device_token"]),
        is_active=bool(saved["is_active"]),
    )


@router.post("/dispatch", response_model=NotificationDispatchResponse)
def dispatch_notification(
    payload: NotificationDispatchRequest,
    current_user_id: str = Depends(get_current_user_id),
) -> NotificationDispatchResponse:
    if not payload.user_id and not payload.profile_id:
        raise HTTPException(status_code=422, detail="user_id or profile_id is required")

    try:
        if payload.user_id and payload.user_id != current_user_id:
            raise HTTPException(status_code=403, detail="Cannot dispatch notifications for another user")

        if payload.profile_id:
            if not profile_access.profile_exists(payload.profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(payload.profile_id, current_user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")

        user_id = payload.user_id
        if user_id is None and payload.profile_id:
            user_id = notification_repository.resolve_user_id_by_profile(payload.profile_id)
        if user_id is None:
            raise HTTPException(status_code=404, detail="Target user not found")
        if user_id != current_user_id:
            raise HTTPException(status_code=403, detail="Cannot dispatch notifications for another user")

        targets = notification_repository.list_active_device_targets(user_id=user_id)
        dispatched, skipped, reason, event_ids, provider_results = notification_dispatcher.dispatch_stub(
            user_id=user_id,
            profile_id=payload.profile_id,
            risk_level=payload.risk_level,
            message=payload.message,
            device_targets=targets,
            force_send=payload.force_send,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc

    return NotificationDispatchResponse(
        dispatched_to_tokens=dispatched,
        skipped=skipped,
        reason=reason,
        event_ids=event_ids,
        provider_results=provider_results,
    )


@router.get("/delivery-attempts", response_model=list[NotificationDeliveryAttemptItem])
def list_delivery_attempts(
    profile_id: str | None = None,
    limit: int = 100,
    current_user_id: str = Depends(get_current_user_id),
) -> list[NotificationDeliveryAttemptItem]:
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=422, detail="limit must be between 1 and 500")
    try:
        if profile_id:
            if not profile_access.profile_exists(profile_id):
                raise HTTPException(status_code=404, detail="Profile not found")
            if not profile_access.profile_belongs_to_user(profile_id, current_user_id):
                raise HTTPException(status_code=403, detail="Profile does not belong to user")
        rows = notification_repository.list_delivery_attempts(
            user_id=current_user_id,
            profile_id=profile_id,
            limit=limit,
        )
    except PsycopgError as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return [NotificationDeliveryAttemptItem(**row) for row in rows]
