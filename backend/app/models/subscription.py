from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

BillingCycle = Literal["monthly", "yearly"]
SubscriptionStatus = Literal[
    "active",
    "inactive",
    "canceled",
    "trialing",
    "grace_period",
    "expired",
    "refunded",
    "unknown",
]
SubscriptionPlatform = Literal["ios", "android", "web", "manual", "stub"]
EntitlementPlan = Literal["free", "premium"]


class SubscriptionPlan(BaseModel):
    plan_id: str
    name: str
    billing_cycle: BillingCycle
    price_usd: float | None = Field(default=None, ge=0)
    trial_days: int = Field(default=0, ge=0)
    ios_product_id: str | None = None
    android_product_id: str | None = None
    is_premium: bool = True


class UserEntitlementResponse(BaseModel):
    user_id: str
    plan: EntitlementPlan = "free"
    is_premium: bool = False
    premium_until: datetime | None = None
    max_profiles: int = 1
    extended_forecast_enabled: bool = False
    custom_alerts_enabled: bool = False
    export_reports_enabled: bool = False
    advanced_insights_enabled: bool = False
    wearable_insights_enabled: bool = False
    priority_notifications_enabled: bool = False


class SubscriptionStatusResponse(BaseModel):
    user_id: str
    plan_id: str | None = None
    status: SubscriptionStatus = "inactive"
    starts_at: datetime | None = None
    current_period_end: datetime | None = None
    auto_renew: bool = False
    platform: SubscriptionPlatform | None = None
    provider: str | None = None
    product_id: str | None = None
    entitlement: UserEntitlementResponse | None = None


class ActivateSubscriptionRequest(BaseModel):
    plan_id: str
    use_trial: bool = True


class IosVerifyRequest(BaseModel):
    signed_transaction: str = Field(min_length=8)
    product_id: str | None = None


class AndroidVerifyRequest(BaseModel):
    product_id: str = Field(min_length=3)
    purchase_token: str = Field(min_length=8)


class RestoreSubscriptionRequest(BaseModel):
    platform: SubscriptionPlatform
    ios_signed_transactions: list[str] = Field(default_factory=list)
    android_purchases: list[AndroidVerifyRequest] = Field(default_factory=list)


class ProviderWebhookEvent(BaseModel):
    event_id: str
    event_type: str
    provider_subscription_id: str
    user_id: str | None = None
    plan_id: str | None = None
    status: SubscriptionStatus | None = None
    current_period_end: datetime | None = None
    auto_renew: bool | None = None
    platform: SubscriptionPlatform | None = None
    product_id: str | None = None
    original_transaction_id: str | None = None
    purchase_token: str | None = None


class SubscriptionWebhookAck(BaseModel):
    accepted: bool = True
    event_id: str
    duplicate: bool = False


class VerifiedStorePurchase(BaseModel):
    platform: SubscriptionPlatform
    provider: str
    product_id: str
    plan_id: str
    status: SubscriptionStatus
    transaction_id: str
    original_transaction_id: str | None = None
    purchase_token: str | None = None
    expires_at: datetime
    auto_renew: bool = True
