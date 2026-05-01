from datetime import datetime, timedelta, timezone
from hashlib import sha256

from psycopg import Error as PsycopgError

from app.core.settings import settings
import app.services.notification_repository as notification_repository
from app.services.secret_store import get_secret


def _fingerprint(secret: str) -> str:
    value = secret.replace("\\n", "\n").encode("utf-8")
    digest = sha256(value).hexdigest()
    return f"sha256:{digest[:12]}"


def _is_overdue(last_rotated_at: str | None) -> bool:
    if not last_rotated_at:
        return True
    try:
        ts = datetime.fromisoformat(last_rotated_at)
    except ValueError:
        return True
    deadline = ts + timedelta(days=max(1, settings.notification_secret_rotation_days))
    return deadline < datetime.now(timezone.utc)


def credentials_health() -> list[dict[str, str | bool | None]]:
    items: list[dict[str, str | bool | None]] = []
    fcm_project_id = get_secret("FCM_PROJECT_ID", settings.fcm_project_id)
    fcm_client_email = get_secret("FCM_CLIENT_EMAIL", settings.fcm_client_email)
    fcm_private_key = get_secret("FCM_PRIVATE_KEY", settings.fcm_private_key)
    fcm_server_key = get_secret("FCM_SERVER_KEY", settings.fcm_server_key)
    apns_team_id = get_secret("APNS_TEAM_ID", settings.apns_team_id)
    apns_key_id = get_secret("APNS_KEY_ID", settings.apns_key_id)
    apns_private_key = get_secret("APNS_PRIVATE_KEY", settings.apns_private_key)
    apns_topic = get_secret("APNS_TOPIC", settings.apns_topic)
    apns_auth_token = get_secret("APNS_AUTH_TOKEN", settings.apns_auth_token)
    provider_configs = [
        (
            "fcm_v1",
            bool(fcm_project_id and fcm_client_email and fcm_private_key),
            _fingerprint(fcm_private_key) if fcm_private_key else None,
        ),
        (
            "fcm_legacy",
            bool(fcm_server_key),
            _fingerprint(fcm_server_key) if fcm_server_key else None,
        ),
        (
            "apns_jwt",
            bool(apns_team_id and apns_key_id and apns_private_key and apns_topic),
            _fingerprint(apns_private_key) if apns_private_key else None,
        ),
        (
            "apns_static",
            bool(apns_auth_token and apns_topic),
            _fingerprint(apns_auth_token) if apns_auth_token else None,
        ),
    ]

    db_available = True
    for provider, configured, key_ref in provider_configs:
        latest = None
        if db_available:
            try:
                latest = notification_repository.get_latest_secret_rotation_event(provider=provider)
            except PsycopgError:
                db_available = False
        last_rotated_at = latest["created_at"] if latest else None
        items.append(
            {
                "provider": provider,
                "configured": configured,
                "key_ref": key_ref,
                "last_rotated_at": last_rotated_at,
                "rotation_overdue": _is_overdue(last_rotated_at) if configured and db_available else False,
            }
        )
    return items
