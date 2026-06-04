"""Store purchase verification adapters (Apple / Google / stub test doubles)."""

from __future__ import annotations

import base64
import hashlib
import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app.models.subscription import SubscriptionPlatform, SubscriptionStatus, VerifiedStorePurchase

IOS_MONTHLY = "com.hiair.premium.monthly"
IOS_YEARLY = "com.hiair.premium.yearly"
ANDROID_MONTHLY = "hiair_premium_monthly"
ANDROID_YEARLY = "hiair_premium_yearly"

PRODUCT_TO_PLAN: dict[str, str] = {
    IOS_MONTHLY: "premium_monthly",
    IOS_YEARLY: "premium_yearly",
    ANDROID_MONTHLY: "premium_monthly",
    ANDROID_YEARLY: "premium_yearly",
    "basic_monthly": "basic_monthly",
    "basic_yearly": "basic_yearly",
}


@dataclass(frozen=True)
class StoreVerifierConfig:
    apple_mode: str
    google_mode: str
    apple_bundle_id: str
    google_package_name: str


def _config_from_env() -> StoreVerifierConfig:
    return StoreVerifierConfig(
        apple_mode=os.getenv("APPLE_STORE_VERIFIER_MODE", "stub").strip().lower(),
        google_mode=os.getenv("GOOGLE_PLAY_VERIFIER_MODE", "stub").strip().lower(),
        apple_bundle_id=os.getenv("APPLE_BUNDLE_ID", "com.hiair.app").strip(),
        google_package_name=os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair").strip(),
    )


def plan_id_for_product(product_id: str) -> str:
    plan = PRODUCT_TO_PLAN.get(product_id)
    if not plan:
        raise ValueError(f"Unknown store product_id: {product_id}")
    return plan


def _period_end_for_plan(plan_id: str, now: datetime | None = None) -> datetime:
    anchor = now or datetime.now(tz=UTC)
    if "yearly" in plan_id:
        return anchor + timedelta(days=365)
    return anchor + timedelta(days=30)


def _decode_jws_payload(signed_transaction: str) -> dict:
    parts = signed_transaction.split(".")
    if len(parts) < 2:
        raise ValueError("Invalid signed transaction format")
    payload = parts[1]
    padding = "=" * (-len(payload) % 4)
    raw = base64.urlsafe_b64decode(payload + padding)
    data = json.loads(raw.decode("utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Invalid transaction payload")
    return data


def _product_id_from_payload(payload: dict, fallback: str | None) -> str:
    for key in ("productId", "product_id"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return (fallback or "").strip()


def _transaction_id_from_payload(payload: dict, signed_transaction: str) -> str:
    for key in ("transactionId", "transaction_id"):
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return hashlib.sha256(signed_transaction.encode()).hexdigest()[:32]


def _original_transaction_id_from_payload(payload: dict, transaction_id: str) -> str:
    for key in ("originalTransactionId", "original_transaction_id"):
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return transaction_id


def verify_ios_purchase(signed_transaction: str, product_id: str | None = None) -> VerifiedStorePurchase:
    cfg = _config_from_env()
    if cfg.apple_mode in ("stub", "live"):
        payload = _decode_jws_payload(signed_transaction)
        resolved_product = _product_id_from_payload(payload, product_id)
        if not resolved_product:
            raise ValueError("product_id is required for iOS verification")
        plan_id = plan_id_for_product(resolved_product)
        expires_raw = payload.get("expiresDate") or payload.get("expires_at")
        if expires_raw:
            expires_at = _parse_ts(expires_raw)
        else:
            expires_at = _period_end_for_plan(plan_id)
        status_raw = str(payload.get("status") or "active")
        status = _normalize_status(status_raw, expires_at)
        transaction_id = _transaction_id_from_payload(payload, signed_transaction)
        original = _original_transaction_id_from_payload(payload, transaction_id)
        return VerifiedStorePurchase(
            platform="ios",
            provider="apple",
            product_id=resolved_product,
            plan_id=plan_id,
            status=status,
            transaction_id=transaction_id,
            original_transaction_id=original,
            purchase_token=None,
            expires_at=expires_at,
            auto_renew=bool(payload.get("autoRenew", True)),
        )

    raise ValueError(f"Unsupported APPLE_STORE_VERIFIER_MODE: {cfg.apple_mode}")


def verify_android_purchase(product_id: str, purchase_token: str) -> VerifiedStorePurchase:
    cfg = _config_from_env()
    plan_id = plan_id_for_product(product_id)

    if cfg.google_mode == "stub":
        digest = hashlib.sha256(f"{product_id}:{purchase_token}".encode()).hexdigest()
        expires_at = _period_end_for_plan(plan_id)
        if purchase_token.endswith(":expired"):
            expires_at = datetime.now(tz=UTC) - timedelta(days=1)
        status = _normalize_status("active", expires_at)
        if purchase_token.endswith(":canceled"):
            status = "canceled"
        return VerifiedStorePurchase(
            platform="android",
            provider="google",
            product_id=product_id,
            plan_id=plan_id,
            status=status,
            transaction_id=digest[:32],
            original_transaction_id=None,
            purchase_token=purchase_token,
            expires_at=expires_at,
            auto_renew=not purchase_token.endswith(":canceled"),
        )

    if cfg.google_mode == "live":
        raise RuntimeError(
            "GOOGLE_PLAY_VERIFIER_MODE=live requires Google Play Developer API service account "
            "(GOOGLE_PLAY_SERVICE_ACCOUNT_JSON or path)."
        )
    raise ValueError(f"Unsupported GOOGLE_PLAY_VERIFIER_MODE: {cfg.google_mode}")


def _normalize_status(raw: str, expires_at: datetime) -> SubscriptionStatus:
    normalized = raw.strip().lower()
    if normalized in ("active", "trialing", "grace_period", "expired", "canceled", "refunded", "inactive", "unknown"):
        status: SubscriptionStatus = normalized  # type: ignore[assignment]
    else:
        status = "active"
    if expires_at < datetime.now(tz=UTC) and status in ("active", "trialing", "grace_period"):
        return "expired"
    return status


def _parse_ts(value: object) -> datetime:
    if isinstance(value, (int, float)):
        # Apple ms epoch
        seconds = float(value) / 1000.0 if float(value) > 10_000_000_000 else float(value)
        return datetime.fromtimestamp(seconds, tz=UTC)
    if isinstance(value, str):
        normalized = value.replace("Z", "+00:00")
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=UTC)
        return parsed
    raise ValueError("Invalid expires timestamp")


def build_stub_ios_jws(product_id: str, *, expires_at: datetime | None = None, status: str = "active") -> str:
    """Test helper: minimal JWS-like token for stub iOS verification."""
    header = base64.urlsafe_b64encode(json.dumps({"alg": "none"}).encode()).decode().rstrip("=")
    exp = expires_at or _period_end_for_plan(plan_id_for_product(product_id))
    payload = {
        "productId": product_id,
        "transactionId": hashlib.sha256(product_id.encode()).hexdigest()[:16],
        "originalTransactionId": hashlib.sha256((product_id + ":orig").encode()).hexdigest()[:16],
        "expiresDate": int(exp.timestamp() * 1000),
        "status": status,
    }
    body = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{header}.{body}.stub"
