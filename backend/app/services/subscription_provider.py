import hashlib
import hmac
import json
from datetime import UTC, datetime
from uuid import uuid4

from app.models.subscription import ProviderWebhookEvent


def parse_webhook_event(provider: str, payload: dict) -> ProviderWebhookEvent:
    normalized_provider = provider.strip().lower()
    if normalized_provider in ("stub", "stripe"):
        return _parse_generic_webhook(payload)
    if normalized_provider in ("apple", "ios"):
        return _parse_apple_webhook(payload)
    if normalized_provider in ("google", "android"):
        return _parse_google_webhook(payload)
    raise ValueError("Unsupported subscription provider")


def _parse_generic_webhook(payload: dict) -> ProviderWebhookEvent:
    data = payload.get("data", payload)
    if not isinstance(data, dict):
        raise ValueError("Invalid webhook payload")

    event_id = payload.get("id") or data.get("id") or str(uuid4())
    event_type = payload.get("type") or data.get("event_type") or "subscription.updated"
    provider_subscription_id = data.get("provider_subscription_id") or data.get("subscription_id")
    if not isinstance(provider_subscription_id, str) or not provider_subscription_id:
        raise ValueError("provider_subscription_id is required")

    current_period_end = _parse_datetime(data.get("current_period_end"))
    status = data.get("status")
    if status is not None and status not in (
        "active",
        "inactive",
        "canceled",
        "trialing",
        "grace_period",
        "expired",
        "refunded",
        "unknown",
    ):
        raise ValueError("Invalid status in webhook payload")

    platform = data.get("platform")
    if platform is not None and platform not in ("ios", "android", "web", "manual", "stub"):
        raise ValueError("Invalid platform in webhook payload")

    return ProviderWebhookEvent(
        event_id=str(event_id),
        event_type=str(event_type),
        provider_subscription_id=provider_subscription_id,
        user_id=data.get("user_id"),
        plan_id=data.get("plan_id"),
        status=status,
        current_period_end=current_period_end,
        auto_renew=data.get("auto_renew"),
        platform=platform,
        product_id=data.get("product_id"),
        original_transaction_id=data.get("original_transaction_id"),
        purchase_token=data.get("purchase_token"),
    )


def _parse_apple_webhook(payload: dict) -> ProviderWebhookEvent:
    """Normalized Apple App Store Server Notifications V2 (simplified envelope)."""
    data = payload.get("data", payload)
    if not isinstance(data, dict):
        raise ValueError("Invalid Apple webhook payload")
    event_id = str(payload.get("notificationUUID") or payload.get("id") or uuid4())
    event_type = str(payload.get("notificationType") or data.get("event_type") or "subscription.updated")
    transaction = data.get("transactionInfo") or data.get("transaction") or data
    if not isinstance(transaction, dict):
        transaction = data
    original_transaction_id = str(
        transaction.get("originalTransactionId") or transaction.get("original_transaction_id") or ""
    )
    if not original_transaction_id:
        raise ValueError("originalTransactionId is required for Apple webhook")
    expires = _parse_datetime(
        transaction.get("expiresDate") or transaction.get("expires_at") or data.get("current_period_end")
    )
    product_id = transaction.get("productId") or transaction.get("product_id")
    return ProviderWebhookEvent(
        event_id=event_id,
        event_type=event_type,
        provider_subscription_id=original_transaction_id,
        user_id=data.get("user_id"),
        plan_id=data.get("plan_id"),
        status=_apple_status_from_type(event_type),
        current_period_end=expires,
        auto_renew=data.get("auto_renew"),
        platform="ios",
        product_id=str(product_id) if product_id else None,
        original_transaction_id=original_transaction_id,
    )


def _parse_google_webhook(payload: dict) -> ProviderWebhookEvent:
    """Real-Time Developer Notifications (Pub/Sub message decoded to JSON)."""
    message = payload.get("message", payload)
    if isinstance(message, dict) and "data" in message:
        decoded = _decode_pubsub_data(message.get("data"))
        payload = decoded
    sub_note = payload.get("subscriptionNotification") or payload.get("data", payload)
    if not isinstance(sub_note, dict):
        raise ValueError("Invalid Google webhook payload")
    event_id = str(payload.get("eventId") or sub_note.get("purchaseToken") or uuid4())
    notification_type = int(sub_note.get("notificationType", 0))
    purchase_token = str(sub_note.get("purchaseToken") or "")
    if not purchase_token:
        raise ValueError("purchaseToken is required for Google webhook")
    product_id = sub_note.get("subscriptionId")
    event_type = _google_notification_type(notification_type)
    return ProviderWebhookEvent(
        event_id=event_id,
        event_type=event_type,
        provider_subscription_id=purchase_token,
        user_id=sub_note.get("user_id"),
        plan_id=sub_note.get("plan_id"),
        status=_google_status_from_type(notification_type),
        current_period_end=_parse_datetime(sub_note.get("expiryTimeMillis")),
        auto_renew=notification_type not in (3, 12, 13),
        platform="android",
        product_id=str(product_id) if product_id else None,
        purchase_token=purchase_token,
    )


def _apple_status_from_type(event_type: str) -> str | None:
    mapping = {
        "DID_RENEW": "active",
        "SUBSCRIBED": "active",
        "DID_FAIL_TO_RENEW": "grace_period",
        "EXPIRED": "expired",
        "REFUND": "refunded",
        "REVOKE": "refunded",
        "GRACE_PERIOD_EXPIRED": "expired",
    }
    return mapping.get(event_type.upper())


def _google_notification_type(code: int) -> str:
    mapping = {
        1: "subscription.recovered",
        2: "subscription.renewed",
        3: "subscription.canceled",
        4: "subscription.purchased",
        12: "subscription.revoked",
        13: "subscription.expired",
    }
    return mapping.get(code, "subscription.updated")


def _google_status_from_type(code: int) -> str | None:
    mapping = {
        1: "active",
        2: "active",
        3: "canceled",
        4: "active",
        12: "refunded",
        13: "expired",
    }
    return mapping.get(code)


def _decode_pubsub_data(data: object) -> dict:
    import base64

    if not isinstance(data, str):
        return {}
    raw = base64.b64decode(data)
    parsed = json.loads(raw.decode("utf-8"))
    return parsed if isinstance(parsed, dict) else {}


def verify_webhook_signature(raw_body: bytes, signature: str | None, secret: str) -> bool:
    if not secret:
        return False
    if not signature:
        return False

    expected = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    token = signature.strip()
    if token.startswith("sha256="):
        token = token[7:]
    return hmac.compare_digest(expected, token)


def verify_apple_webhook_signature(raw_body: bytes, signature: str | None, secret: str) -> bool:
    return verify_webhook_signature(raw_body, signature, secret)


def verify_google_webhook_token(token: str | None, expected: str) -> bool:
    if not expected or not token:
        return False
    return hmac.compare_digest(token.strip(), expected.strip())


def canonical_json_bytes(payload: dict) -> bytes:
    return json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")


def _parse_datetime(value: object) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        seconds = float(value) / 1000.0 if float(value) > 10_000_000_000 else float(value)
        return datetime.fromtimestamp(seconds, tz=UTC)
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value
    if not isinstance(value, str) or not value:
        return None
    normalized = value.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed
