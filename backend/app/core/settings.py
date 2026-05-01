import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql://hiair:hiair@localhost:5432/hiair",
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-only-change-me")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    access_token_ttl_minutes: int = int(os.getenv("ACCESS_TOKEN_TTL_MINUTES", "120"))
    refresh_token_ttl_days: int = int(os.getenv("REFRESH_TOKEN_TTL_DAYS", "30"))
    allow_legacy_user_header_auth: bool = (
        os.getenv("ALLOW_LEGACY_USER_HEADER_AUTH", "false").strip().lower() == "true"
    )
    subscription_provider: str = os.getenv("SUBSCRIPTION_PROVIDER", "stub")
    subscription_webhook_secret: str = os.getenv("SUBSCRIPTION_WEBHOOK_SECRET", "")
    weather_api_provider: str = os.getenv("WEATHER_API_PROVIDER", "openweathermap")
    weather_api_key: str = os.getenv("WEATHER_API_KEY", "")
    aqi_api_provider: str = os.getenv("AQI_API_PROVIDER", "waqi")
    aqi_api_key: str = os.getenv("AQI_API_KEY", "")
    openai_api_key: str = os.getenv("OPENAI_API_KEY", "")
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    openai_base_url: str = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1/chat/completions")
    openai_prompt_version: str = os.getenv("OPENAI_PROMPT_VERSION", "hiair-expl-v1")
    notifications_provider_mode: str = os.getenv("NOTIFICATIONS_PROVIDER_MODE", "stub")
    fcm_server_key: str = os.getenv("FCM_SERVER_KEY", "")
    fcm_project_id: str = os.getenv("FCM_PROJECT_ID", "")
    fcm_client_email: str = os.getenv("FCM_CLIENT_EMAIL", "")
    fcm_private_key: str = os.getenv("FCM_PRIVATE_KEY", "")
    apns_auth_token: str = os.getenv("APNS_AUTH_TOKEN", "")
    apns_topic: str = os.getenv("APNS_TOPIC", "")
    apns_team_id: str = os.getenv("APNS_TEAM_ID", "")
    apns_key_id: str = os.getenv("APNS_KEY_ID", "")
    apns_private_key: str = os.getenv("APNS_PRIVATE_KEY", "")
    notification_max_attempts: int = int(os.getenv("NOTIFICATION_MAX_ATTEMPTS", "3"))
    notification_retry_backoff_ms: int = int(os.getenv("NOTIFICATION_RETRY_BACKOFF_MS", "300"))
    notification_secret_rotation_days: int = int(os.getenv("NOTIFICATION_SECRET_ROTATION_DAYS", "30"))
    retention_notification_delivery_attempts_days: int = int(
        os.getenv("RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS", "90")
    )
    retention_notification_events_days: int = int(os.getenv("RETENTION_NOTIFICATION_EVENTS_DAYS", "180"))
    retention_subscription_webhook_events_days: int = int(
        os.getenv("RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS", "180")
    )
    retention_secret_rotation_events_days: int = int(
        os.getenv("RETENTION_SECRET_ROTATION_EVENTS_DAYS", "365")
    )
    notification_admin_token: str = os.getenv("NOTIFICATION_ADMIN_TOKEN", "")
    secret_source: str = os.getenv("SECRET_SOURCE", "env")
    secret_file_path: str = os.getenv("SECRET_FILE_PATH", "")
    secret_http_url: str = os.getenv("SECRET_HTTP_URL", "")
    secret_http_token: str = os.getenv("SECRET_HTTP_TOKEN", "")
    secret_http_timeout_ms: int = int(os.getenv("SECRET_HTTP_TIMEOUT_MS", "4000"))
    secret_cache_ttl_seconds: int = int(os.getenv("SECRET_CACHE_TTL_SECONDS", "60"))
    vault_addr: str = os.getenv("VAULT_ADDR", "")
    vault_token: str = os.getenv("VAULT_TOKEN", "")
    vault_namespace: str = os.getenv("VAULT_NAMESPACE", "")
    vault_kv_mount: str = os.getenv("VAULT_KV_MOUNT", "secret")
    vault_kv_path: str = os.getenv("VAULT_KV_PATH", "hiair")
    app_env: str = os.getenv("APP_ENV", "development")


settings = Settings()


def _is_protected_env(env_name: str) -> bool:
    return env_name.strip().lower() in {"production", "staging"}


def validate_runtime_settings(current: Settings) -> None:
    if _is_protected_env(current.app_env):
        if not current.jwt_secret or current.jwt_secret == "dev-only-change-me":
            raise RuntimeError("JWT_SECRET must be explicitly configured in protected environments.")
        if current.allow_legacy_user_header_auth:
            raise RuntimeError("Legacy X-User-Id auth must be disabled in protected environments.")
