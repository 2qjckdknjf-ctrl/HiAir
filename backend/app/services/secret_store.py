import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

from app.core.settings import settings

_cache: dict[str, str] | None = None
_cache_expires_at: datetime | None = None
_last_load_error: str | None = None


def _load_file_secrets() -> dict[str, str]:
    if not settings.secret_file_path:
        return {}
    path = Path(settings.secret_file_path)
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    if not isinstance(payload, dict):
        return {}
    result: dict[str, str] = {}
    for key, value in payload.items():
        if isinstance(key, str) and isinstance(value, str):
            result[key] = value
    return result


def _load_http_secrets() -> dict[str, str]:
    if not settings.secret_http_url:
        return {}
    headers: dict[str, str] = {}
    if settings.secret_http_token:
        headers["Authorization"] = f"Bearer {settings.secret_http_token}"
    timeout_s = max(0.5, settings.secret_http_timeout_ms / 1000.0)
    try:
        with httpx.Client(timeout=timeout_s) as client:
            response = client.get(settings.secret_http_url, headers=headers)
        if response.status_code != 200:
            return {}
        payload = response.json()
    except (httpx.HTTPError, ValueError):
        return {}

    if not isinstance(payload, dict):
        return {}
    candidates = payload.get("secrets", payload)
    if not isinstance(candidates, dict):
        return {}
    result: dict[str, str] = {}
    for key, value in candidates.items():
        if isinstance(key, str) and isinstance(value, str):
            result[key] = value
    return result


def _load_vault_kv_v2_secrets() -> dict[str, str]:
    if not settings.vault_addr or not settings.vault_token:
        return {}
    mount = settings.vault_kv_mount.strip("/")
    path = settings.vault_kv_path.strip("/")
    if not mount or not path:
        return {}

    url = f"{settings.vault_addr.rstrip('/')}/v1/{mount}/data/{path}"
    headers = {"X-Vault-Token": settings.vault_token}
    if settings.vault_namespace:
        headers["X-Vault-Namespace"] = settings.vault_namespace
    timeout_s = max(0.5, settings.secret_http_timeout_ms / 1000.0)
    try:
        with httpx.Client(timeout=timeout_s) as client:
            response = client.get(url, headers=headers)
        if response.status_code != 200:
            return {}
        payload = response.json()
    except (httpx.HTTPError, ValueError):
        return {}

    if not isinstance(payload, dict):
        return {}
    data_block = payload.get("data", {})
    if not isinstance(data_block, dict):
        return {}
    data = data_block.get("data", {})
    if not isinstance(data, dict):
        return {}
    result: dict[str, str] = {}
    for key, value in data.items():
        if isinstance(key, str) and isinstance(value, str):
            result[key] = value
    return result


def _load_source_secrets() -> dict[str, str]:
    source = settings.secret_source.lower()
    if source == "file":
        return _load_file_secrets()
    if source == "http":
        return _load_http_secrets()
    if source == "vault":
        return _load_vault_kv_v2_secrets()
    return {}


def _is_cache_valid(now: datetime) -> bool:
    if _cache is None:
        return False
    if _cache_expires_at is None:
        return False
    return _cache_expires_at > now


def _read_cached_secrets() -> dict[str, str]:
    global _cache, _cache_expires_at, _last_load_error
    now = datetime.now(timezone.utc)
    if _is_cache_valid(now):
        return _cache if _cache is not None else {}

    try:
        _cache = _load_source_secrets()
        _last_load_error = None
    except Exception as exc:
        _cache = {}
        _last_load_error = str(exc)
    ttl_seconds = max(1, settings.secret_cache_ttl_seconds)
    _cache_expires_at = now + timedelta(seconds=ttl_seconds)
    return _cache


def refresh_secret_cache() -> None:
    global _cache, _cache_expires_at, _last_load_error
    _cache = None
    _cache_expires_at = None
    _last_load_error = None


def get_secret(name: str, env_fallback: str = "") -> str:
    source = settings.secret_source.lower()
    if source in ("file", "http", "vault"):
        cached = _read_cached_secrets()
        return cached.get(name, env_fallback)
    return env_fallback


def secret_store_health() -> dict[str, str | int | bool | None]:
    now = datetime.now(timezone.utc)
    cache_entries = len(_cache) if _cache is not None else 0
    cache_expires_at = _cache_expires_at.isoformat() if _cache_expires_at else None
    cache_valid = _is_cache_valid(now)
    return {
        "source": settings.secret_source.lower(),
        "cache_entries": cache_entries,
        "cache_valid": cache_valid,
        "cache_expires_at": cache_expires_at,
        "last_error": _last_load_error,
    }
