import time

from app.core.settings import settings
from app.services.notification_repository import (
    save_delivery_attempt,
    save_notification_event,
    update_notification_event_status,
)
from app.services.notification_providers import provider_for_platform


def should_dispatch(risk_level: str, force_send: bool) -> tuple[bool, str]:
    if force_send:
        return True, "forced"
    if risk_level in ("high", "very_high"):
        return True, "risk level requires notification"
    return False, "risk level below dispatch threshold"


def dispatch_stub(
    user_id: str | None,
    profile_id: str | None,
    risk_level: str,
    message: str,
    device_targets: list[dict[str, str]],
    force_send: bool = False,
) -> tuple[int, bool, str, list[str], dict[str, int]]:
    send, reason = should_dispatch(risk_level=risk_level, force_send=force_send)
    if not send:
        return 0, True, reason, [], {}

    event_ids: list[str] = []
    provider_results: dict[str, int] = {}
    for target in device_targets:
        platform = target["platform"]
        token = target["device_token"]
        provider = provider_for_platform(platform)
        last_result = None
        max_attempts = max(1, settings.notification_max_attempts)
        event_id = save_notification_event(
            profile_id=profile_id,
            risk_level=risk_level,
            should_send=False,
            message=message,
        )
        for attempt_no in range(1, max_attempts + 1):
            result = provider.send(device_token=token, message=message)
            last_result = result
            save_delivery_attempt(
                event_id=event_id,
                user_id=user_id,
                platform=platform,
                device_token=token,
                provider_mode=settings.notifications_provider_mode,
                attempt_no=attempt_no,
                success=result.delivered,
                status_code=result.status_code,
                reason=result.reason,
            )
            if result.delivered:
                break
            if not result.transient:
                break
            if attempt_no < max_attempts:
                backoff_s = max(0.0, settings.notification_retry_backoff_ms / 1000.0) * attempt_no
                time.sleep(backoff_s)

        if last_result is None:
            continue
        update_notification_event_status(event_id=event_id, should_send=last_result.delivered)
        provider_results[last_result.reason] = provider_results.get(last_result.reason, 0) + 1
        event_ids.append(event_id)
    return len(device_targets), False, "dispatch completed with provider adapters", event_ids, provider_results
