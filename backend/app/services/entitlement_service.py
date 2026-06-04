"""User entitlements — backend source of truth for premium feature access."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime

from fastapi import HTTPException

from app.models.subscription import UserEntitlementResponse
from app.services.db import get_connection

FREE_MAX_PROFILES = 1
PREMIUM_MAX_PROFILES = 6


@dataclass(frozen=True)
class EntitlementLimits:
    max_profiles: int
    extended_forecast_enabled: bool
    custom_alerts_enabled: bool
    export_reports_enabled: bool
    advanced_insights_enabled: bool
    wearable_insights_enabled: bool
    priority_notifications_enabled: bool


def _free_entitlement(user_id: str) -> UserEntitlementResponse:
    return UserEntitlementResponse(
        user_id=user_id,
        plan="free",
        is_premium=False,
        premium_until=None,
        max_profiles=FREE_MAX_PROFILES,
        extended_forecast_enabled=False,
        custom_alerts_enabled=False,
        export_reports_enabled=False,
        advanced_insights_enabled=False,
        wearable_insights_enabled=False,
        priority_notifications_enabled=False,
    )


def _premium_entitlement(user_id: str, premium_until: datetime | None, source_subscription_id: str | None) -> UserEntitlementResponse:
    return UserEntitlementResponse(
        user_id=user_id,
        plan="premium",
        is_premium=True,
        premium_until=premium_until,
        max_profiles=PREMIUM_MAX_PROFILES,
        extended_forecast_enabled=True,
        custom_alerts_enabled=True,
        export_reports_enabled=True,
        advanced_insights_enabled=True,
        wearable_insights_enabled=False,
        priority_notifications_enabled=True,
    )


def _row_to_entitlement(row: dict) -> UserEntitlementResponse:
    return UserEntitlementResponse(
        user_id=str(row["user_id"]),
        plan=row["plan"],
        is_premium=bool(row["is_premium"]),
        premium_until=row.get("premium_until"),
        max_profiles=int(row["max_profiles"]),
        extended_forecast_enabled=bool(row["extended_forecast_enabled"]),
        custom_alerts_enabled=bool(row["custom_alerts_enabled"]),
        export_reports_enabled=bool(row["export_reports_enabled"]),
        advanced_insights_enabled=bool(row["advanced_insights_enabled"]),
        wearable_insights_enabled=bool(row.get("wearable_insights_enabled", False)),
        priority_notifications_enabled=bool(row.get("priority_notifications_enabled", False)),
    )


def get_current_entitlement(user_id: str) -> UserEntitlementResponse:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT user_id, plan, is_premium, premium_until, max_profiles,
                       extended_forecast_enabled, custom_alerts_enabled,
                       export_reports_enabled, advanced_insights_enabled,
                       wearable_insights_enabled, priority_notifications_enabled
                FROM user_entitlements
                WHERE user_id = %s
                """,
                (user_id,),
            )
            row = cur.fetchone()
    if row is None:
        return _free_entitlement(user_id)
    ent = _row_to_entitlement(row)
    if ent.is_premium and ent.premium_until and ent.premium_until < datetime.now(tz=UTC):
        upsert_free_entitlement(user_id)
        return _free_entitlement(user_id)
    return ent


def get_subscription_limits(user_id: str) -> EntitlementLimits:
    ent = get_current_entitlement(user_id)
    return EntitlementLimits(
        max_profiles=ent.max_profiles,
        extended_forecast_enabled=ent.extended_forecast_enabled,
        custom_alerts_enabled=ent.custom_alerts_enabled,
        export_reports_enabled=ent.export_reports_enabled,
        advanced_insights_enabled=ent.advanced_insights_enabled,
        wearable_insights_enabled=ent.wearable_insights_enabled,
        priority_notifications_enabled=ent.priority_notifications_enabled,
    )


def require_premium(user_id: str, *, feature: str) -> UserEntitlementResponse:
    ent = get_current_entitlement(user_id)
    if not ent.is_premium:
        raise HTTPException(
            status_code=402,
            detail=f"Premium subscription required for {feature}",
        )
    return ent


def require_feature(user_id: str, feature: str, enabled_attr: str) -> UserEntitlementResponse:
    ent = require_premium(user_id, feature=feature)
    if not getattr(ent, enabled_attr, False):
        raise HTTPException(
            status_code=402,
            detail=f"Premium feature '{feature}' is not enabled",
        )
    return ent


def assert_profile_limit(user_id: str) -> None:
    limits = get_subscription_limits(user_id)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*)::int AS cnt FROM profiles WHERE user_id = %s",
                (user_id,),
            )
            row = cur.fetchone()
    count = int(row["cnt"]) if row else 0
    if count >= limits.max_profiles:
        raise HTTPException(
            status_code=402,
            detail=f"Profile limit reached ({limits.max_profiles}). Upgrade to Premium for family profiles.",
        )


def sync_entitlement_from_subscription(
    user_id: str,
    *,
    is_premium: bool,
    premium_until: datetime | None,
    source_subscription_id: str | None,
) -> UserEntitlementResponse:
    if is_premium:
        ent = _premium_entitlement(user_id, premium_until, source_subscription_id)
    else:
        ent = _free_entitlement(user_id)
    upsert_entitlement_row(user_id, ent, source_subscription_id)
    return ent


def upsert_free_entitlement(user_id: str) -> UserEntitlementResponse:
    ent = _free_entitlement(user_id)
    upsert_entitlement_row(user_id, ent, None)
    return ent


def upsert_entitlement_row(
    user_id: str,
    ent: UserEntitlementResponse,
    source_subscription_id: str | None,
) -> None:
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO user_entitlements (
                    user_id, plan, is_premium, premium_until, source_subscription_id,
                    max_profiles, extended_forecast_enabled, custom_alerts_enabled,
                    export_reports_enabled, advanced_insights_enabled,
                    wearable_insights_enabled, priority_notifications_enabled, updated_at
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
                ON CONFLICT (user_id) DO UPDATE SET
                    plan = EXCLUDED.plan,
                    is_premium = EXCLUDED.is_premium,
                    premium_until = EXCLUDED.premium_until,
                    source_subscription_id = EXCLUDED.source_subscription_id,
                    max_profiles = EXCLUDED.max_profiles,
                    extended_forecast_enabled = EXCLUDED.extended_forecast_enabled,
                    custom_alerts_enabled = EXCLUDED.custom_alerts_enabled,
                    export_reports_enabled = EXCLUDED.export_reports_enabled,
                    advanced_insights_enabled = EXCLUDED.advanced_insights_enabled,
                    wearable_insights_enabled = EXCLUDED.wearable_insights_enabled,
                    priority_notifications_enabled = EXCLUDED.priority_notifications_enabled,
                    updated_at = NOW()
                """,
                (
                    user_id,
                    ent.plan,
                    ent.is_premium,
                    ent.premium_until,
                    source_subscription_id,
                    ent.max_profiles,
                    ent.extended_forecast_enabled,
                    ent.custom_alerts_enabled,
                    ent.export_reports_enabled,
                    ent.advanced_insights_enabled,
                    ent.wearable_insights_enabled,
                    ent.priority_notifications_enabled,
                ),
            )
