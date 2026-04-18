from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

BillingCycle = Literal["monthly", "yearly"]
SubscriptionStatus = Literal["active", "inactive", "canceled", "trialing"]


class SubscriptionPlan(BaseModel):
    plan_id: str
    name: str
    billing_cycle: BillingCycle
    price_usd: float = Field(ge=0)
    trial_days: int = Field(ge=0)


class SubscriptionStatusResponse(BaseModel):
    user_id: str
    plan_id: str | None = None
    status: SubscriptionStatus = "inactive"
    starts_at: datetime | None = None
    current_period_end: datetime | None = None
    auto_renew: bool = False


class ActivateSubscriptionRequest(BaseModel):
    plan_id: str
    use_trial: bool = True


class ProviderWebhookEvent(BaseModel):
    event_id: str
    event_type: str
    provider_subscription_id: str
    user_id: str | None = None
    plan_id: str | None = None
    status: SubscriptionStatus | None = None
    current_period_end: datetime | None = None
    auto_renew: bool | None = None


class SubscriptionWebhookAck(BaseModel):
    accepted: bool = True
    event_id: str
    duplicate: bool = False
