import hashlib
import hmac
import json
from datetime import UTC, datetime
from uuid import uuid4

from app.models.subscription import ProviderWebhookEvent


def parse_webhook_event(provider: str, payload: dict) -> ProviderWebhookEvent:
    if provider not in ("stub", "stripe"):
        raise ValueError("Unsupported subscription provider")

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
    if status is not None and status not in ("active", "inactive", "canceled", "trialing"):
        raise ValueError("Invalid status in webhook payload")

    return ProviderWebhookEvent(
        event_id=str(event_id),
        event_type=str(event_type),
        provider_subscription_id=provider_subscription_id,
        user_id=data.get("user_id"),
        plan_id=data.get("plan_id"),
        status=status,
        current_period_end=current_period_end,
        auto_renew=data.get("auto_renew"),
    )


def verify_webhook_signature(raw_body: bytes, signature: str | None, secret: str) -> bool:
    if not secret:
        return True
    if not signature:
        return False

    expected = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    token = signature.strip()
    if token.startswith("sha256="):
        token = token[7:]
    return hmac.compare_digest(expected, token)


def canonical_json_bytes(payload: dict) -> bytes:
    return json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8")


def _parse_datetime(value: object) -> datetime | None:
    if value is None:
        return None
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
