from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
import jwt

from app.core.settings import settings
from app.services.secret_store import get_secret, refresh_secret_cache


@dataclass
class ProviderResult:
    delivered: bool
    reason: str
    status_code: int | None = None
    transient: bool = False


class PushProvider:
    def send(self, device_token: str, message: str) -> ProviderResult:
        raise NotImplementedError()


def _normalize_pem(value: str) -> str:
    return value.replace("\\n", "\n")


_fcm_token_cache: dict[str, Any] = {"token": None, "expires_at": None}
_apns_token_cache: dict[str, Any] = {"token": None, "expires_at": None}


def _get_fcm_v1_access_token() -> str | None:
    fcm_client_email = get_secret("FCM_CLIENT_EMAIL", settings.fcm_client_email)
    fcm_private_key = get_secret("FCM_PRIVATE_KEY", settings.fcm_private_key)
    if not fcm_client_email or not fcm_private_key:
        return None

    now = datetime.now(timezone.utc)
    cached_token = _fcm_token_cache.get("token")
    cached_expiry = _fcm_token_cache.get("expires_at")
    if cached_token and isinstance(cached_expiry, datetime) and cached_expiry > now + timedelta(minutes=2):
        return cached_token

    private_key = _normalize_pem(fcm_private_key)
    assertion = jwt.encode(
        {
            "iss": fcm_client_email,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": "https://oauth2.googleapis.com/token",
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(minutes=55)).timestamp()),
        },
        private_key,
        algorithm="RS256",
    )
    response = httpx.post(
        "https://oauth2.googleapis.com/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=8.0,
    )
    if response.status_code != 200:
        return None
    payload = response.json()
    token = payload.get("access_token")
    expires_in = int(payload.get("expires_in", 3600))
    if not token:
        return None
    _fcm_token_cache["token"] = token
    _fcm_token_cache["expires_at"] = now + timedelta(seconds=expires_in)
    return token


def _get_apns_bearer_token() -> str | None:
    apns_auth_token = get_secret("APNS_AUTH_TOKEN", settings.apns_auth_token)
    apns_team_id = get_secret("APNS_TEAM_ID", settings.apns_team_id)
    apns_key_id = get_secret("APNS_KEY_ID", settings.apns_key_id)
    apns_private_key = get_secret("APNS_PRIVATE_KEY", settings.apns_private_key)
    if apns_auth_token:
        return apns_auth_token
    if not apns_team_id or not apns_key_id or not apns_private_key:
        return None

    now = datetime.now(timezone.utc)
    cached_token = _apns_token_cache.get("token")
    cached_expiry = _apns_token_cache.get("expires_at")
    if cached_token and isinstance(cached_expiry, datetime) and cached_expiry > now + timedelta(minutes=2):
        return cached_token

    private_key = _normalize_pem(apns_private_key)
    token = jwt.encode(
        {"iss": apns_team_id, "iat": int(now.timestamp())},
        private_key,
        algorithm="ES256",
        headers={"alg": "ES256", "kid": apns_key_id},
    )
    _apns_token_cache["token"] = token
    _apns_token_cache["expires_at"] = now + timedelta(minutes=50)
    return token


class StubPushProvider(PushProvider):
    def __init__(self, platform: str) -> None:
        self.platform = platform

    def send(self, device_token: str, message: str) -> ProviderResult:
        _ = device_token
        _ = message
        return ProviderResult(delivered=True, reason=f"{self.platform} stub delivery", transient=False)


class FCMPushProvider(PushProvider):
    def send(self, device_token: str, message: str) -> ProviderResult:
        if settings.notifications_provider_mode != "live":
            return ProviderResult(delivered=True, reason="fcm adapter dry-run", transient=False)
        if get_secret("FCM_SERVER_KEY", settings.fcm_server_key):
            return self._send_fcm_legacy(device_token=device_token, message=message)
        return self._send_fcm_v1(device_token=device_token, message=message)

    def _send_fcm_legacy(self, device_token: str, message: str) -> ProviderResult:
        fcm_server_key = get_secret("FCM_SERVER_KEY", settings.fcm_server_key)
        if not fcm_server_key:
            return ProviderResult(delivered=False, reason="fcm server key missing", transient=False)

        payload = {
            "to": device_token,
            "notification": {"title": "HiAir Alert", "body": message},
            "priority": "high",
        }
        headers = {
            "Authorization": f"key={fcm_server_key}",
            "Content-Type": "application/json",
        }
        try:
            with httpx.Client(timeout=8.0) as client:
                response = client.post("https://fcm.googleapis.com/fcm/send", json=payload, headers=headers)
            if 200 <= response.status_code < 300:
                return ProviderResult(delivered=True, reason="fcm delivered", status_code=response.status_code)
            transient = response.status_code in (408, 429, 500, 502, 503, 504)
            return ProviderResult(
                delivered=False,
                reason=f"fcm http {response.status_code}",
                status_code=response.status_code,
                transient=transient,
            )
        except httpx.TimeoutException:
            return ProviderResult(delivered=False, reason="fcm timeout", transient=True)
        except httpx.HTTPError:
            return ProviderResult(delivered=False, reason="fcm network error", transient=True)

    def _send_fcm_v1(self, device_token: str, message: str) -> ProviderResult:
        fcm_project_id = get_secret("FCM_PROJECT_ID", settings.fcm_project_id)
        if not fcm_project_id:
            return ProviderResult(delivered=False, reason="fcm project id missing", transient=False)
        access_token = _get_fcm_v1_access_token()
        if not access_token:
            return ProviderResult(delivered=False, reason="fcm v1 auth failed", transient=True)
        url = f"https://fcm.googleapis.com/v1/projects/{fcm_project_id}/messages:send"
        payload = {
            "message": {
                "token": device_token,
                "notification": {"title": "HiAir Alert", "body": message},
            }
        }
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        try:
            with httpx.Client(timeout=8.0) as client:
                response = client.post(url, json=payload, headers=headers)
            if 200 <= response.status_code < 300:
                return ProviderResult(delivered=True, reason="fcm v1 delivered", status_code=response.status_code)
            transient = response.status_code in (408, 429, 500, 502, 503, 504)
            return ProviderResult(
                delivered=False,
                reason=f"fcm v1 http {response.status_code}",
                status_code=response.status_code,
                transient=transient,
            )
        except httpx.TimeoutException:
            return ProviderResult(delivered=False, reason="fcm v1 timeout", transient=True)
        except httpx.HTTPError:
            return ProviderResult(delivered=False, reason="fcm v1 network error", transient=True)


class APNsPushProvider(PushProvider):
    def send(self, device_token: str, message: str) -> ProviderResult:
        if settings.notifications_provider_mode != "live":
            return ProviderResult(delivered=True, reason="apns adapter dry-run", transient=False)
        bearer_token = _get_apns_bearer_token()
        apns_topic = get_secret("APNS_TOPIC", settings.apns_topic)
        if not bearer_token or not apns_topic:
            return ProviderResult(delivered=False, reason="apns credentials missing", transient=False)

        endpoint = f"https://api.push.apple.com/3/device/{device_token}"
        headers = {
            "authorization": f"bearer {bearer_token}",
            "apns-topic": apns_topic,
            "apns-push-type": "alert",
            "content-type": "application/json",
        }
        payload = {"aps": {"alert": message, "sound": "default"}}
        try:
            with httpx.Client(timeout=8.0, http2=True) as client:
                response = client.post(endpoint, json=payload, headers=headers)
            if 200 <= response.status_code < 300:
                return ProviderResult(delivered=True, reason="apns delivered", status_code=response.status_code)
            transient = response.status_code in (408, 429, 500, 502, 503, 504)
            return ProviderResult(
                delivered=False,
                reason=f"apns http {response.status_code}",
                status_code=response.status_code,
                transient=transient,
            )
        except httpx.TimeoutException:
            return ProviderResult(delivered=False, reason="apns timeout", transient=True)
        except httpx.HTTPError:
            return ProviderResult(delivered=False, reason="apns network error", transient=True)


def provider_for_platform(platform: str) -> PushProvider:
    platform_key = platform.lower()
    if platform_key == "android":
        return FCMPushProvider()
    if platform_key == "ios":
        return APNsPushProvider()
    return StubPushProvider(platform=platform_key)


def refresh_provider_secrets() -> None:
    _fcm_token_cache["token"] = None
    _fcm_token_cache["expires_at"] = None
    _apns_token_cache["token"] = None
    _apns_token_cache["expires_at"] = None
    refresh_secret_cache()
