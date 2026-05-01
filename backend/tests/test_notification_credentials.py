from psycopg import OperationalError

import app.services.notification_credentials as notification_credentials


def test_credentials_health_survives_db_unavailable(monkeypatch) -> None:
    secrets = {
        "FCM_PROJECT_ID": "project",
        "FCM_CLIENT_EMAIL": "bot@hiair.app",
        "FCM_PRIVATE_KEY": "private-key",
        "FCM_SERVER_KEY": "server-key",
        "APNS_TEAM_ID": "team",
        "APNS_KEY_ID": "key",
        "APNS_PRIVATE_KEY": "apns-key",
        "APNS_TOPIC": "com.hiair.app",
        "APNS_AUTH_TOKEN": "auth-token",
    }
    monkeypatch.setattr(
        notification_credentials,
        "get_secret",
        lambda key, default=None: secrets.get(key, default),
    )
    monkeypatch.setattr(
        notification_credentials.notification_repository,
        "get_latest_secret_rotation_event",
        lambda provider: (_ for _ in ()).throw(OperationalError("db unavailable")),
    )

    items = notification_credentials.credentials_health()

    assert len(items) == 4
    assert all(item["configured"] is True for item in items)
    assert all(item["last_rotated_at"] is None for item in items)
    assert all(item["rotation_overdue"] is False for item in items)
