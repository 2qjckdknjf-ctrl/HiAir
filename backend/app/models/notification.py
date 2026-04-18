from pydantic import BaseModel

from app.models.risk import RiskEstimateResponse


class NotificationPreviewRequest(BaseModel):
    risk: RiskEstimateResponse
    profile_id: str | None = None


class NotificationPreviewResponse(BaseModel):
    should_send: bool
    text: str
    risk_level: str
    event_id: str | None = None


class DeviceTokenRegisterRequest(BaseModel):
    platform: str
    device_token: str
    profile_id: str | None = None


class DeviceTokenRegisterResponse(BaseModel):
    id: str
    user_id: str
    profile_id: str | None
    platform: str
    device_token: str
    is_active: bool


class NotificationDispatchRequest(BaseModel):
    risk_level: str
    message: str
    user_id: str | None = None
    profile_id: str | None = None
    force_send: bool = False


class NotificationDispatchResponse(BaseModel):
    dispatched_to_tokens: int
    skipped: bool
    reason: str
    event_ids: list[str]
    provider_results: dict[str, int]


class NotificationProviderHealthResponse(BaseModel):
    secret_source: str
    mode: str
    fcm_legacy_configured: bool
    fcm_v1_configured: bool
    apns_static_token_configured: bool
    apns_jwt_configured: bool


class NotificationDeliveryAttemptItem(BaseModel):
    id: str
    event_id: str
    user_id: str | None
    profile_id: str | None
    platform: str
    provider_mode: str
    attempt_no: int
    success: bool
    status_code: int | None
    reason: str
    created_at: str


class NotificationCredentialHealthItem(BaseModel):
    provider: str
    configured: bool
    key_ref: str | None
    last_rotated_at: str | None
    rotation_overdue: bool


class NotificationCredentialsHealthResponse(BaseModel):
    mode: str
    policy_rotation_days: int
    items: list[NotificationCredentialHealthItem]


class NotificationCredentialsRotateRequest(BaseModel):
    provider: str
    key_ref: str | None = None
    rotated_by: str | None = None
    notes: str | None = None


class NotificationCredentialsRotateResponse(BaseModel):
    id: str
    provider: str
    created_at: str


class NotificationSecretsRefreshResponse(BaseModel):
    refreshed: bool
    secret_source: str


class SecretStoreHealthResponse(BaseModel):
    source: str
    cache_entries: int
    cache_valid: bool
    cache_expires_at: str | None
    last_error: str | None
