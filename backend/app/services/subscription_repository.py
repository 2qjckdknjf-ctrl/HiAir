from datetime import UTC, datetime, timedelta
from uuid import uuid4

from app.models.subscription import (
    ProviderWebhookEvent,
    SubscriptionPlan,
    SubscriptionStatusResponse,
    UserEntitlementResponse,
    VerifiedStorePurchase,
)
from app.services import entitlement_service
from app.services.db import get_connection
from app.services.subscription_store import plan_id_for_product

PLANS: dict[str, SubscriptionPlan] = {
    "premium_monthly": SubscriptionPlan(
        plan_id="premium_monthly",
        name="HiAir Premium Monthly",
        billing_cycle="monthly",
        ios_product_id="com.hiair.premium.monthly",
        android_product_id="hiair_premium_monthly",
    ),
    "premium_yearly": SubscriptionPlan(
        plan_id="premium_yearly",
        name="HiAir Premium Yearly",
        billing_cycle="yearly",
        ios_product_id="com.hiair.premium.yearly",
        android_product_id="hiair_premium_yearly",
    ),
    "basic_monthly": SubscriptionPlan(
        plan_id="basic_monthly",
        name="HiAir Basic Monthly (stub)",
        billing_cycle="monthly",
        price_usd=4.99,
        trial_days=7,
    ),
    "basic_yearly": SubscriptionPlan(
        plan_id="basic_yearly",
        name="HiAir Basic Yearly (stub)",
        billing_cycle="yearly",
        price_usd=49.99,
        trial_days=14,
    ),
}


def list_plans() -> list[SubscriptionPlan]:
    return list(PLANS.values())


def get_user_subscription(user_id: str) -> SubscriptionStatusResponse:
    entitlement = entitlement_service.get_current_entitlement(user_id)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, user_id, plan_id, status, starts_at, current_period_end, auto_renew,
                       platform, provider, product_id
                FROM user_subscriptions
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
    if row is None:
        return SubscriptionStatusResponse(user_id=user_id, entitlement=entitlement)
    return SubscriptionStatusResponse(
        user_id=str(row["user_id"]),
        plan_id=_as_text(row["plan_id"]),
        status=_as_text(row["status"]) or "inactive",
        starts_at=row["starts_at"],
        current_period_end=row["current_period_end"],
        auto_renew=row["auto_renew"],
        platform=_as_text(row.get("platform")),
        provider=_as_text(row.get("provider")),
        product_id=_as_text(row.get("product_id")),
        entitlement=entitlement,
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
    sub_id = str(uuid4())
    provider_sub_id = f"stub_{uuid4()}"

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_subscriptions (
                    id, user_id, plan_id, status, starts_at, current_period_end, auto_renew,
                    provider_subscription_id, platform, provider, product_id, last_verified_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, TRUE, %s, 'stub', 'stub', %s, NOW())
                ON CONFLICT (user_id) DO UPDATE SET
                    plan_id = EXCLUDED.plan_id,
                    status = EXCLUDED.status,
                    starts_at = EXCLUDED.starts_at,
                    current_period_end = EXCLUDED.current_period_end,
                    auto_renew = EXCLUDED.auto_renew,
                    provider_subscription_id = EXCLUDED.provider_subscription_id,
                    platform = EXCLUDED.platform,
                    provider = EXCLUDED.provider,
                    product_id = EXCLUDED.product_id,
                    last_verified_at = NOW(),
                    updated_at = NOW()
                RETURNING id, user_id, plan_id, status, starts_at, current_period_end, auto_renew,
                          platform, provider, product_id
                """,
                (
                    sub_id,
                    user_id,
                    plan_id,
                    status,
                    now,
                    period_end,
                    provider_sub_id,
                    plan_id,
                ),
            )
            row = cur.fetchone()

    entitlement_service.sync_entitlement_from_subscription(
        user_id,
        is_premium=True,
        premium_until=period_end,
        source_subscription_id=str(row["id"]),
    )
    return get_user_subscription(user_id)


def apply_verified_purchase(user_id: str, purchase: VerifiedStorePurchase) -> SubscriptionStatusResponse:
    now = datetime.now(tz=UTC)
    is_premium = purchase.status in ("active", "trialing", "grace_period")
    sub_id = str(uuid4())
    provider_sub_id = purchase.original_transaction_id or purchase.purchase_token or purchase.transaction_id

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_subscriptions (
                    id, user_id, plan_id, status, starts_at, current_period_end, auto_renew,
                    provider_subscription_id, platform, provider, product_id,
                    original_transaction_id, purchase_token, latest_transaction_id, last_verified_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (user_id) DO UPDATE SET
                    plan_id = EXCLUDED.plan_id,
                    status = EXCLUDED.status,
                    current_period_end = EXCLUDED.current_period_end,
                    auto_renew = EXCLUDED.auto_renew,
                    provider_subscription_id = EXCLUDED.provider_subscription_id,
                    platform = EXCLUDED.platform,
                    provider = EXCLUDED.provider,
                    product_id = EXCLUDED.product_id,
                    original_transaction_id = EXCLUDED.original_transaction_id,
                    purchase_token = EXCLUDED.purchase_token,
                    latest_transaction_id = EXCLUDED.latest_transaction_id,
                    last_verified_at = NOW(),
                    updated_at = NOW()
                RETURNING id
                """,
                (
                    sub_id,
                    user_id,
                    purchase.plan_id,
                    purchase.status,
                    now,
                    purchase.expires_at,
                    purchase.auto_renew,
                    provider_sub_id,
                    purchase.platform,
                    purchase.provider,
                    purchase.product_id,
                    purchase.original_transaction_id,
                    purchase.purchase_token,
                    purchase.transaction_id,
                ),
            )
            row = cur.fetchone()
            subscription_row_id = str(row["id"])

            cur.execute(
                """
                INSERT INTO provider_transactions (
                    id, user_id, platform, provider, product_id, transaction_id,
                    original_transaction_id, purchase_token, status, expires_at, raw_payload
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::jsonb)
                ON CONFLICT (provider, transaction_id) DO UPDATE SET
                    status = EXCLUDED.status,
                    expires_at = EXCLUDED.expires_at,
                    verified_at = NOW()
                """,
                (
                    str(uuid4()),
                    user_id,
                    purchase.platform,
                    purchase.provider,
                    purchase.product_id,
                    purchase.transaction_id,
                    purchase.original_transaction_id,
                    purchase.purchase_token,
                    purchase.status,
                    purchase.expires_at,
                    "{}",
                ),
            )

    entitlement_service.sync_entitlement_from_subscription(
        user_id,
        is_premium=is_premium,
        premium_until=purchase.expires_at if is_premium else None,
        source_subscription_id=subscription_row_id,
    )
    return get_user_subscription(user_id)


def cancel_subscription(user_id: str) -> SubscriptionStatusResponse:
    now = datetime.now(tz=UTC)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE user_subscriptions
                SET status = 'canceled', auto_renew = FALSE, canceled_at = %s, updated_at = NOW()
                WHERE user_id = %s
                RETURNING id
                """,
                (now, user_id),
            )
            row = cur.fetchone()
    if row is None:
        entitlement_service.upsert_free_entitlement(user_id)
        return SubscriptionStatusResponse(user_id=user_id, entitlement=entitlement_service.get_current_entitlement(user_id))

    entitlement_service.sync_entitlement_from_subscription(
        user_id,
        is_premium=False,
        premium_until=None,
        source_subscription_id=str(row["id"]),
    )
    return get_user_subscription(user_id)


def has_active_subscription(user_id: str) -> bool:
    ent = entitlement_service.get_current_entitlement(user_id)
    return ent.is_premium


def has_active_subscription_for_profile(profile_id: str) -> bool:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT user_id FROM profiles WHERE id = %s LIMIT 1",
                (profile_id,),
            )
            row = cur.fetchone()
    if row is None:
        return False
    return has_active_subscription(str(row["user_id"]))


def apply_provider_webhook_event(event: ProviderWebhookEvent) -> SubscriptionStatusResponse:
    now = datetime.now(tz=UTC)
    status = event.status or _status_from_event_type(event.event_type)
    if status not in (
        "active",
        "inactive",
        "canceled",
        "trialing",
        "grace_period",
        "expired",
        "refunded",
        "unknown",
    ):
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
                       OR original_transaction_id = %s
                       OR purchase_token = %s
                    LIMIT 1
                    """,
                    (
                        event.provider_subscription_id,
                        event.original_transaction_id or "",
                        event.purchase_token or "",
                    ),
                )
                mapped = cur.fetchone()
                if mapped is None:
                    raise ValueError("Cannot resolve user_id for provider subscription")
                user_id = str(mapped["user_id"])

            cur.execute(
                """
                SELECT id, plan_id, starts_at, current_period_end
                FROM user_subscriptions
                WHERE user_id = %s
                LIMIT 1
                """,
                (user_id,),
            )
            existing = cur.fetchone()

            plan_id = event.plan_id or (_as_text(existing["plan_id"]) if existing else "premium_monthly")
            if event.product_id:
                try:
                    plan_id = plan_id_for_product(event.product_id)
                except ValueError:
                    pass
            starts_at = existing["starts_at"] if existing else now
            period_end = event.current_period_end or (
                existing["current_period_end"] if existing else now
            )
            auto_renew = event.auto_renew if event.auto_renew is not None else status not in ("canceled", "expired", "refunded")
            sub_id = str(existing["id"]) if existing else str(uuid4())

            cur.execute(
                """
                INSERT INTO user_subscriptions (
                    id, user_id, plan_id, status, starts_at, current_period_end, auto_renew,
                    provider_subscription_id, platform, provider, product_id,
                    original_transaction_id, purchase_token, last_verified_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (user_id) DO UPDATE SET
                    plan_id = EXCLUDED.plan_id,
                    status = EXCLUDED.status,
                    starts_at = EXCLUDED.starts_at,
                    current_period_end = EXCLUDED.current_period_end,
                    auto_renew = EXCLUDED.auto_renew,
                    provider_subscription_id = EXCLUDED.provider_subscription_id,
                    platform = COALESCE(EXCLUDED.platform, user_subscriptions.platform),
                    provider = COALESCE(EXCLUDED.provider, user_subscriptions.provider),
                    product_id = COALESCE(EXCLUDED.product_id, user_subscriptions.product_id),
                    original_transaction_id = COALESCE(EXCLUDED.original_transaction_id, user_subscriptions.original_transaction_id),
                    purchase_token = COALESCE(EXCLUDED.purchase_token, user_subscriptions.purchase_token),
                    last_verified_at = NOW(),
                    updated_at = NOW()
                RETURNING id, current_period_end
                """,
                (
                    sub_id,
                    user_id,
                    plan_id,
                    status,
                    starts_at,
                    period_end,
                    auto_renew,
                    event.provider_subscription_id,
                    event.platform,
                    _provider_name(event),
                    event.product_id,
                    event.original_transaction_id,
                    event.purchase_token,
                ),
            )
            updated = cur.fetchone()

    is_premium = status in ("active", "trialing", "grace_period") and period_end >= datetime.now(tz=UTC)
    entitlement_service.sync_entitlement_from_subscription(
        user_id,
        is_premium=is_premium,
        premium_until=period_end if is_premium else None,
        source_subscription_id=str(updated["id"]),
    )
    return get_user_subscription(user_id)


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


def _provider_name(event: ProviderWebhookEvent) -> str | None:
    if event.platform == "ios":
        return "apple"
    if event.platform == "android":
        return "google"
    return None


def _status_from_event_type(event_type: str) -> str:
    normalized = event_type.strip().lower()
    mapping = {
        "subscription.created": "active",
        "subscription.updated": "active",
        "subscription.renewed": "active",
        "subscription.trialing": "trialing",
        "subscription.canceled": "canceled",
        "subscription.expired": "expired",
        "subscription.refunded": "refunded",
        "invoice.payment_failed": "grace_period",
        "did_renew": "active",
        "did_fail_to_renew": "grace_period",
        "expired": "expired",
        "revoked": "refunded",
    }
    return mapping.get(normalized, "active")


def _as_text(value: object | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8")
    return str(value)
