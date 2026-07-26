"""Store purchase verification adapters (Apple / Google / stub test doubles)."""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
import jwt

from app.models.subscription import SubscriptionStatus, VerifiedStorePurchase

logger = logging.getLogger(__name__)

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

_APPLE_ROOT_CERT_DIR = Path(__file__).resolve().parents[1] / "resources" / "apple_root_certs"

# Injected in unit tests to supply a cryptographically verified Apple transaction payload.
_apple_transaction_decoder = None


@dataclass(frozen=True)
class StoreVerifierConfig:
    apple_mode: str
    google_mode: str
    apple_bundle_id: str
    google_package_name: str
    apple_environment: str
    apple_app_apple_id: int | None


def _config_from_env() -> StoreVerifierConfig:
    app_apple_id_raw = os.getenv("APPLE_APP_APPLE_ID", "").strip()
    app_apple_id: int | None = None
    if app_apple_id_raw:
        try:
            app_apple_id = int(app_apple_id_raw)
        except ValueError as exc:
            raise RuntimeError("APPLE_APP_APPLE_ID must be an integer") from exc
    return StoreVerifierConfig(
        apple_mode=os.getenv("APPLE_STORE_VERIFIER_MODE", "stub").strip().lower(),
        google_mode=os.getenv("GOOGLE_PLAY_VERIFIER_MODE", "stub").strip().lower(),
        apple_bundle_id=os.getenv("APPLE_BUNDLE_ID", "com.hiair.app").strip(),
        google_package_name=os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair").strip(),
        apple_environment=os.getenv("APPLE_STORE_ENVIRONMENT", "sandbox").strip().lower(),
        apple_app_apple_id=app_apple_id,
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


def _decode_jws_payload_unverified(signed_transaction: str) -> dict:
    """Decode JWS payload without signature checks. Stub / inspection only."""
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


def _jws_alg(signed_transaction: str) -> str:
    parts = signed_transaction.split(".")
    if len(parts) < 1:
        return ""
    header = parts[0]
    padding = "=" * (-len(header) % 4)
    try:
        raw = base64.urlsafe_b64decode(header + padding)
        data = json.loads(raw.decode("utf-8"))
    except (ValueError, json.JSONDecodeError):
        return ""
    if not isinstance(data, dict):
        return ""
    alg = data.get("alg")
    return str(alg).strip() if alg is not None else ""


def _product_id_from_payload(payload: dict, fallback: str | None) -> str:
    for key in ("productId", "product_id"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return (fallback or "").strip()


def _transaction_id_from_payload(payload: dict) -> str:
    for key in ("transactionId", "transaction_id", "transaction_id_numeric"):
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


def _original_transaction_id_from_payload(payload: dict) -> str:
    for key in ("originalTransactionId", "original_transaction_id"):
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


def _require_live_field(payload: dict, *keys: str) -> object:
    for key in keys:
        value = payload.get(key)
        if value is not None and str(value).strip():
            return value
    raise ValueError(f"Apple transaction missing required field: {keys[0]}")


def _load_apple_root_certificates() -> list[bytes]:
    if not _APPLE_ROOT_CERT_DIR.is_dir():
        raise RuntimeError("Apple root certificate directory is missing")
    certs: list[bytes] = []
    for path in sorted(_APPLE_ROOT_CERT_DIR.glob("*.cer")):
        data = path.read_bytes()
        if data:
            certs.append(data)
    if not certs:
        raise RuntimeError("Apple root certificates are unavailable")
    return certs


def _resolve_apple_environment(name: str):
    from appstoreserverlibrary.models.Environment import Environment

    normalized = name.strip().lower()
    if normalized in ("production", "prod"):
        return Environment.PRODUCTION
    if normalized == "sandbox":
        return Environment.SANDBOX
    if normalized == "xcode":
        return Environment.XCODE
    if normalized in ("localtesting", "local_testing", "local"):
        return Environment.LOCAL_TESTING
    raise RuntimeError(
        f"Unknown APPLE_STORE_ENVIRONMENT={name!r}; expected sandbox, production, xcode, or localtesting"
    )


def _build_apple_signed_data_verifier(cfg: StoreVerifierConfig):
    from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier

    environment = _resolve_apple_environment(cfg.apple_environment)
    app_apple_id = cfg.apple_app_apple_id
    if environment.name == "PRODUCTION" and app_apple_id is None:
        raise RuntimeError("APPLE_APP_APPLE_ID is required when APPLE_STORE_ENVIRONMENT=production")
    return SignedDataVerifier(
        _load_apple_root_certificates(),
        True,
        environment,
        cfg.apple_bundle_id,
        app_apple_id,
    )


def _verified_payload_from_apple_object(decoded: object) -> dict:
    """Normalize library / mock decoded transaction into a plain dict."""
    if isinstance(decoded, dict):
        return decoded

    def _attr(name: str):
        value = getattr(decoded, name, None)
        if value is None:
            return None
        # Enum-like (Environment, etc.)
        if hasattr(value, "value"):
            return value.value
        return value

    payload = {
        "bundleId": _attr("bundleId") or _attr("bundle_id"),
        "environment": _attr("environment"),
        "productId": _attr("productId") or _attr("product_id"),
        "transactionId": _attr("transactionId") or _attr("transaction_id"),
        "originalTransactionId": _attr("originalTransactionId") or _attr("original_transaction_id"),
        "expiresDate": _attr("expiresDate") or _attr("expires_date"),
        "revocationDate": _attr("revocationDate") or _attr("revocation_date"),
        "revocationReason": _attr("revocationReason") or _attr("revocation_reason"),
        "type": _attr("type"),
        "inAppOwnershipType": _attr("inAppOwnershipType"),
        "transactionReason": _attr("transactionReason"),
    }
    return {key: value for key, value in payload.items() if value is not None}


def verify_and_decode_apple_signed_transaction(signed_transaction: str, cfg: StoreVerifierConfig) -> dict:
    """
    Cryptographically verify an App Store signed transaction (fail-closed).

    Never logs the signed transaction or receipt body.
    """
    if _apple_transaction_decoder is not None:
        return _verified_payload_from_apple_object(_apple_transaction_decoder(signed_transaction, cfg))

    alg = _jws_alg(signed_transaction)
    if not alg or alg.lower() == "none":
        raise ValueError("Apple transaction signature algorithm is missing or untrusted")

    try:
        from appstoreserverlibrary.signed_data_verifier import VerificationException
    except ImportError as exc:
        raise RuntimeError("Apple App Store Server Library is not installed") from exc

    try:
        verifier = _build_apple_signed_data_verifier(cfg)
        decoded = verifier.verify_and_decode_signed_transaction(signed_transaction)
    except VerificationException as exc:
        logger.warning("apple_jws_verification_failed status=%s", getattr(exc, "status", "unknown"))
        raise ValueError("Apple transaction verification failed") from exc
    except Exception as exc:  # network / cert / config — fail closed
        logger.warning("apple_jws_verifier_unavailable error_type=%s", type(exc).__name__)
        raise RuntimeError("Apple transaction verifier unavailable") from exc

    return _verified_payload_from_apple_object(decoded)


def _status_from_apple_payload(payload: dict, expires_at: datetime) -> SubscriptionStatus:
    now = datetime.now(tz=UTC)
    if payload.get("revocationDate") is not None:
        return "refunded"
    status_raw = str(payload.get("status") or "active")
    status = _normalize_status(status_raw, expires_at)
    if expires_at < now and status in ("active", "trialing", "grace_period"):
        return "expired"
    return status


def _verify_ios_live(signed_transaction: str, product_id: str | None, cfg: StoreVerifierConfig) -> VerifiedStorePurchase:
    payload = verify_and_decode_apple_signed_transaction(signed_transaction, cfg)

    bundle_id = str(_require_live_field(payload, "bundleId", "bundle_id")).strip()
    if bundle_id != cfg.apple_bundle_id:
        raise ValueError("Apple transaction bundle ID mismatch")

    environment = str(_require_live_field(payload, "environment")).strip()
    expected_env = _resolve_apple_environment(cfg.apple_environment)
    expected_value = getattr(expected_env, "value", str(expected_env))
    if environment != expected_value and environment.lower() != str(expected_value).lower():
        raise ValueError("Apple transaction environment mismatch")

    resolved_product = str(_require_live_field(payload, "productId", "product_id")).strip()
    if product_id and product_id.strip() and resolved_product != product_id.strip():
        raise ValueError("Apple transaction product ID mismatch")
    plan_id = plan_id_for_product(resolved_product)

    expires_raw = _require_live_field(payload, "expiresDate", "expires_date", "expirationDate", "expires_at")
    expires_at = _parse_ts(expires_raw)

    transaction_id = str(_require_live_field(payload, "transactionId", "transaction_id", "transaction_id_numeric")).strip()
    original = str(
        _require_live_field(payload, "originalTransactionId", "original_transaction_id")
    ).strip()

    status = _status_from_apple_payload(payload, expires_at)

    logger.info(
        "apple_live_verify product_id=%s status=%s expires_at=%s",
        resolved_product,
        status,
        expires_at.isoformat(),
    )
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
        auto_renew=bool(payload.get("autoRenew", True)) and status in ("active", "trialing", "grace_period"),
    )


def _verify_ios_stub(signed_transaction: str, product_id: str | None) -> VerifiedStorePurchase:
    payload = _decode_jws_payload_unverified(signed_transaction)
    resolved_product = _product_id_from_payload(payload, product_id)
    if not resolved_product:
        raise ValueError("product_id is required for iOS verification")
    plan_id = plan_id_for_product(resolved_product)
    expires_raw = (
        payload.get("expiresDate")
        or payload.get("expires_date")
        or payload.get("expirationDate")
        or payload.get("expires_at")
    )
    if expires_raw:
        expires_at = _parse_ts(expires_raw)
    else:
        expires_at = _period_end_for_plan(plan_id)
    status_raw = str(payload.get("status") or "active")
    status = _normalize_status(status_raw, expires_at)
    transaction_id = _transaction_id_from_payload(payload) or hashlib.sha256(signed_transaction.encode()).hexdigest()[:32]
    original = _original_transaction_id_from_payload(payload) or transaction_id
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


def verify_ios_purchase(signed_transaction: str, product_id: str | None = None) -> VerifiedStorePurchase:
    cfg = _config_from_env()
    if cfg.apple_mode == "stub":
        return _verify_ios_stub(signed_transaction, product_id)
    if cfg.apple_mode == "live":
        # Fail-closed: never silently fall back to stub decode.
        return _verify_ios_live(signed_transaction, product_id, cfg)
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
        # Fail-closed: never silently fall back to stub decode / synthesized fields.
        return _verify_google_play_live(cfg.google_package_name, product_id, purchase_token)
    raise ValueError(f"Unsupported GOOGLE_PLAY_VERIFIER_MODE: {cfg.google_mode}")


def _load_google_service_account() -> dict:
    raw = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        raise RuntimeError(
            "GOOGLE_PLAY_VERIFIER_MODE=live requires GOOGLE_PLAY_SERVICE_ACCOUNT_JSON "
            "(inline JSON or path to service account file)."
        )
    if raw.startswith("{") or raw.startswith("["):
        data = json.loads(raw)
    else:
        with open(raw, encoding="utf-8") as handle:
            data = json.load(handle)
    if not isinstance(data, dict):
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON must decode to a JSON object")
    client_email = data.get("client_email")
    private_key = data.get("private_key")
    if not isinstance(client_email, str) or not client_email.strip():
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing client_email")
    if not isinstance(private_key, str) or not private_key.strip():
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing private_key")
    return data


def _google_access_token(service_account: dict) -> str:
    now = int(time.time())
    payload = {
        "iss": service_account["client_email"],
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": "https://oauth2.googleapis.com/token",
        "iat": now,
        "exp": now + 3600,
    }
    assertion = jwt.encode(payload, service_account["private_key"], algorithm="RS256")
    response = httpx.post(
        "https://oauth2.googleapis.com/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=20.0,
    )
    response.raise_for_status()
    token = response.json().get("access_token")
    if not isinstance(token, str) or not token:
        raise RuntimeError("Google OAuth token exchange failed")
    return token


def _google_fetch_subscription_v2(package_name: str, purchase_token: str, access_token: str) -> dict:
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{package_name}/purchases/subscriptionsv2/tokens/{purchase_token}"
    )
    response = httpx.get(url, headers={"Authorization": f"Bearer {access_token}"}, timeout=20.0)
    if response.status_code == 404:
        raise ValueError("Google Play purchase token not found")
    response.raise_for_status()
    data = response.json()
    if not isinstance(data, dict):
        raise ValueError("Invalid Google Play subscription response")
    return data


def _google_line_item_for_product(data: dict, product_id: str) -> dict:
    """Return the unique line item for product_id. Ambiguous duplicates fail closed."""
    line_items = data.get("lineItems")
    if not isinstance(line_items, list) or not line_items:
        raise ValueError("Google Play subscription missing lineItems")
    matches = [
        item
        for item in line_items
        if isinstance(item, dict) and str(item.get("productId") or "").strip() == product_id
    ]
    if not matches:
        raise ValueError("Google Play subscription product ID mismatch")
    if len(matches) > 1:
        raise ValueError(
            "Google Play subscription has ambiguous duplicate lineItems for product"
        )
    return matches[0]


def _google_auto_renew_from_line_item(line_item: dict) -> bool:
    """
    Fail-closed auto-renew mapping for subscriptions v2 line items.

    - prepaidPlan => False (never synthesize True)
    - autoRenewingPlan requires an explicit boolean autoRenewEnabled
    - missing / both plan types / non-boolean => reject (no default True)
    """
    prepaid = line_item.get("prepaidPlan")
    auto_renewing = line_item.get("autoRenewingPlan")
    has_prepaid = isinstance(prepaid, dict)
    has_auto = isinstance(auto_renewing, dict)
    if has_prepaid and has_auto:
        raise ValueError("Google Play line item has both prepaidPlan and autoRenewingPlan")
    if has_prepaid:
        return False
    if not has_auto:
        raise ValueError("Google Play line item missing autoRenewingPlan or prepaidPlan")
    if "autoRenewEnabled" not in auto_renewing:
        raise ValueError("Google Play autoRenewingPlan missing autoRenewEnabled")
    enabled = auto_renewing["autoRenewEnabled"]
    if not isinstance(enabled, bool):
        raise ValueError("Google Play autoRenewEnabled must be a boolean")
    return enabled


def _google_require_transaction_id(data: dict) -> str:
    latest_order_id = data.get("latestOrderId")
    if latest_order_id is not None and str(latest_order_id).strip():
        return str(latest_order_id).strip()
    raise ValueError("Google Play subscription missing latestOrderId")


def _google_status_from_subscription(
    data: dict,
    product_id: str,
) -> tuple[SubscriptionStatus, datetime, bool, str]:
    """
    Map a Google Play subscriptions v2 payload to entitlement fields (fail-closed).

    Live mode never synthesizes expiry from plan length or transaction IDs from
    purchase-token hashes.
    """
    now = datetime.now(tz=UTC)
    line_item = _google_line_item_for_product(data, product_id)
    expiry_raw = line_item.get("expiryTime")
    if expiry_raw is None or not str(expiry_raw).strip():
        raise ValueError("Google Play subscription missing expiryTime")
    expires_at = _parse_ts(expiry_raw)
    transaction_id = _google_require_transaction_id(data)

    auto_renew = _google_auto_renew_from_line_item(line_item)

    state_raw = str(data.get("subscriptionState") or "").strip()
    if not state_raw or state_raw == "SUBSCRIPTION_STATE_UNSPECIFIED":
        raise ValueError("Google Play subscription missing subscriptionState")

    if expires_at < now:
        return "expired", expires_at, False, transaction_id

    state_map: dict[str, SubscriptionStatus] = {
        "SUBSCRIPTION_STATE_ACTIVE": "active",
        "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace_period",
        "SUBSCRIPTION_STATE_PENDING": "inactive",
        "SUBSCRIPTION_STATE_PAUSED": "inactive",
        "SUBSCRIPTION_STATE_ON_HOLD": "inactive",
        "SUBSCRIPTION_STATE_EXPIRED": "expired",
        "SUBSCRIPTION_STATE_CANCELED": "canceled",
    }
    if state_raw not in state_map:
        raise ValueError(f"Google Play subscription unrecognized state: {state_raw}")
    status = state_map[state_raw]
    if status == "canceled" and expires_at >= now:
        # Canceled but still within paid period — access continues without renew.
        status = "active"
        auto_renew = False

    return status, expires_at, auto_renew, transaction_id


def verified_purchase_from_google_subscription(
    data: dict,
    *,
    package_name: str,
    product_id: str,
    purchase_token: str,
) -> VerifiedStorePurchase:
    """
    Fail-closed mapping from a Google Play subscriptions v2 response.

    Used by the live verifier and unit tests (no network). Never logs tokens.
    """
    if not package_name.strip():
        raise ValueError("Google Play package name is required")
    if not product_id.strip():
        raise ValueError("Google Play product ID is required")
    if not purchase_token.strip():
        raise ValueError("Google Play purchase token is required")

    response_package = data.get("packageName") or data.get("package_name")
    if response_package is not None and str(response_package).strip():
        if str(response_package).strip() != package_name.strip():
            raise ValueError("Google Play package name mismatch")

    plan_id = plan_id_for_product(product_id)
    status, expires_at, auto_renew, transaction_id = _google_status_from_subscription(data, product_id)
    return VerifiedStorePurchase(
        platform="android",
        provider="google",
        product_id=product_id,
        plan_id=plan_id,
        status=status,
        transaction_id=transaction_id,
        original_transaction_id=None,
        purchase_token=purchase_token,
        expires_at=expires_at,
        auto_renew=auto_renew,
    )


def _verify_google_play_live(package_name: str, product_id: str, purchase_token: str) -> VerifiedStorePurchase:
    if not package_name.strip():
        raise RuntimeError("GOOGLE_PLAY_PACKAGE_NAME is required for live verification")
    if not purchase_token.strip():
        raise ValueError("Google Play purchase token is required")
    plan_id_for_product(product_id)  # unknown product fail-closed before network
    service_account = _load_google_service_account()
    try:
        access_token = _google_access_token(service_account)
        data = _google_fetch_subscription_v2(package_name, purchase_token, access_token)
    except ValueError:
        raise
    except Exception as exc:  # network / oauth / transport — fail closed
        logger.warning("google_play_verifier_unavailable error_type=%s", type(exc).__name__)
        raise RuntimeError("Google Play verifier unavailable") from exc

    purchase = verified_purchase_from_google_subscription(
        data,
        package_name=package_name,
        product_id=product_id,
        purchase_token=purchase_token,
    )
    logger.info(
        "google_play_verify product_id=%s subscription_state=%s status=%s expires_at=%s",
        product_id,
        data.get("subscriptionState"),
        purchase.status,
        purchase.expires_at.isoformat(),
    )
    return purchase


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


def build_unsigned_ios_jws(payload: dict, *, alg: str = "none") -> str:
    """Test helper: unsigned / tampered JWS shapes (never accepted in live mode)."""
    header = base64.urlsafe_b64encode(json.dumps({"alg": alg}).encode()).decode().rstrip("=")
    body = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    return f"{header}.{body}."
