from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.models.subscription import ProviderWebhookEvent, SubscriptionPlan, SubscriptionStatusResponse
from app.services.db import get_connection

PLANS: dict[str, SubscriptionPlan] = {
    "basic_monthly": SubscriptionPlan(
        plan_id="basic_monthly",
        name="HiAir Basic Monthly",
        billing_cycle="monthly",
        price_usd=4.99,
        trial_days=7,
    ),
    "basic_yearly": SubscriptionPlan(
        plan_id="basic_yearly",
        name="HiAir Basic Yearly",
        billing_cycle="yearly",
        price_usd=49.99,
        trial_days=14,
    ),
}


def list_plans() -> list[SubscriptionPlan]:
    return list(PLANS.values())


def get_user_subscription(user_id: str) -> SubscriptionStatusResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT user_id, plan_id, status, starts_at, current_period_end, auto_renew
                FROM user_subscriptions
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
    if row is None:
        return SubscriptionStatusResponse(user_id=user_id)
    return SubscriptionStatusResponse(
        user_id=str(row["user_id"]),
        plan_id=_as_text(row["plan_id"]),
        status=_as_text(row["status"]),
        starts_at=row["starts_at"],
        current_period_end=row["current_period_end"],
        auto_renew=row["auto_renew"],
    )


def activate_subscription(user_id: str, plan_id: str, use_trial: bool) -> SubscriptionStatusResponse:
    plan = PLANS.get(plan_id)
    if not plan:
        raise ValueError("Unknown plan_id")

    now = datetime.now(tz=UTC)
    trial_days = plan.trial_days if use_trial else 0
    if plan.billing_cycle == "monthly":
        period_end = now + timedelta(days=30 + trial_days)
    else:
        period_end = now + timedelta(days=365 + trial_days)
    status = "trialing" if trial_days > 0 else "active"

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_subscriptions (
                    id, user_id, plan_id, status, starts_at, current_period_end, auto_renew, provider_subscription_id
                )
                VALUES (%s, %s, %s, %s, %s, %s, TRUE, %s)
                ON CONFLICT (user_id) DO UPDATE SET
                    plan_id = EXCLUDED.plan_id,
                    status = EXCLUDED.status,
                    starts_at = EXCLUDED.starts_at,
                    current_period_end = EXCLUDED.current_period_end,
                    auto_renew = EXCLUDED.auto_renew,
                    provider_subscription_id = EXCLUDED.provider_subscription_id,
                    updated_at = NOW()
                RETURNING user_id, plan_id, status, starts_at, current_period_end, auto_renew
                """,
                (
                    str(uuid4()),
                    user_id,
                    plan_id,
                    status,
                    now,
                    period_end,
                    f"stub_{uuid4()}",
                ),
            )
            row = cur.fetchone()
    return SubscriptionStatusResponse(
        user_id=str(row["user_id"]),
        plan_id=_as_text(row["plan_id"]),
        status=_as_text(row["status"]),
        starts_at=row["starts_at"],
        current_period_end=row["current_period_end"],
        auto_renew=row["auto_renew"],
    )


def cancel_subscription(user_id: str) -> SubscriptionStatusResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE user_subscriptions
                SET status = 'canceled', auto_renew = FALSE, updated_at = NOW()
                WHERE user_id = %s
                RETURNING user_id, plan_id, status, starts_at, current_period_end, auto_renew
                """,
                (user_id,),
            )
            row = cur.fetchone()
    if row is None:
        return SubscriptionStatusResponse(user_id=user_id)
    return SubscriptionStatusResponse(
        user_id=str(row["user_id"]),
        plan_id=_as_text(row["plan_id"]),
        status=_as_text(row["status"]),
        starts_at=row["starts_at"],
        current_period_end=row["current_period_end"],
        auto_renew=row["auto_renew"],
    )


def has_active_subscription(user_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM user_subscriptions
                WHERE user_id = %s
                  AND status IN ('active', 'trialing')
                  AND current_period_end >= NOW()
                LIMIT 1
                """,
                (user_id,),
            )
            row = cur.fetchone()
    return row is not None


def has_active_subscription_for_profile(profile_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM profiles p
                JOIN user_subscriptions s ON s.user_id = p.user_id
                WHERE p.id = %s
                  AND s.status IN ('active', 'trialing')
                  AND s.current_period_end >= NOW()
                LIMIT 1
                """,
                (profile_id,),
            )
            row = cur.fetchone()
    return row is not None


def apply_provider_webhook_event(event: ProviderWebhookEvent) -> SubscriptionStatusResponse:
    now = datetime.now(tz=UTC)
    status = event.status or _status_from_event_type(event.event_type)
    if status not in ("active", "inactive", "canceled", "trialing"):
        raise ValueError("Unsupported subscription status")

    with get_connection() as conn:
        with conn.cursor() as cur:
            user_id = event.user_id
            if not user_id:
                cur.execute(
                    """
                    SELECT user_id
                    FROM user_subscriptions
                    WHERE provider_subscription_id = %s
                    LIMIT 1
                    """,
                    (event.provider_subscription_id,),
                )
                mapped = cur.fetchone()
                if mapped is None:
                    raise ValueError("Cannot resolve user_id for provider subscription")
                user_id = str(mapped["user_id"])

            cur.execute(
                """
                SELECT plan_id, starts_at, current_period_end
                FROM user_subscriptions
                WHERE user_id = %s
                LIMIT 1
                """,
                (user_id,),
            )
            existing = cur.fetchone()

            plan_id = event.plan_id or (_as_text(existing["plan_id"]) if existing else "basic_monthly")
            starts_at = existing["starts_at"] if existing else now
            period_end = event.current_period_end or (
                existing["current_period_end"] if existing else now
            )
            auto_renew = event.auto_renew if event.auto_renew is not None else status != "canceled"

            cur.execute(
                """
                INSERT INTO user_subscriptions (
                    id, user_id, plan_id, status, starts_at, current_period_end, auto_renew, provider_subscription_id
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (user_id) DO UPDATE SET
                    plan_id = EXCLUDED.plan_id,
                    status = EXCLUDED.status,
                    starts_at = EXCLUDED.starts_at,
                    current_period_end = EXCLUDED.current_period_end,
                    auto_renew = EXCLUDED.auto_renew,
                    provider_subscription_id = EXCLUDED.provider_subscription_id,
                    updated_at = NOW()
                RETURNING user_id, plan_id, status, starts_at, current_period_end, auto_renew
                """,
                (
                    str(uuid4()),
                    user_id,
                    plan_id,
                    status,
                    starts_at,
                    period_end,
                    auto_renew,
                    event.provider_subscription_id,
                ),
            )
            row = cur.fetchone()

    return SubscriptionStatusResponse(
        user_id=str(row["user_id"]),
        plan_id=_as_text(row["plan_id"]),
        status=_as_text(row["status"]),
        starts_at=row["starts_at"],
        current_period_end=row["current_period_end"],
        auto_renew=row["auto_renew"],
    )


def record_webhook_event(provider: str, event: ProviderWebhookEvent) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO subscription_webhook_events (
                    id, provider, event_id, event_type, provider_subscription_id, received_at
                )
                VALUES (%s, %s, %s, %s, %s, NOW())
                ON CONFLICT (provider, event_id) DO NOTHING
                RETURNING id
                """,
                (
                    str(uuid4()),
                    provider,
                    event.event_id,
                    event.event_type,
                    event.provider_subscription_id,
                ),
            )
            row = cur.fetchone()
    return row is not None


def _status_from_event_type(event_type: str) -> str:
    normalized = event_type.strip().lower()
    mapping = {
        "subscription.created": "active",
        "subscription.updated": "active",
        "subscription.renewed": "active",
        "subscription.trialing": "trialing",
        "subscription.canceled": "canceled",
        "subscription.expired": "inactive",
        "invoice.payment_failed": "inactive",
    }
    return mapping.get(normalized, "active")


def _as_text(value: object | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8")
    return str(value)
