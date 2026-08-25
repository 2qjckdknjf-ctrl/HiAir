import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

_backend_root = Path(__file__).resolve().parents[2]
load_dotenv(_backend_root / ".env")
load_dotenv(_backend_root / ".env.local")
load_dotenv()


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql://hiair:hiair@localhost:5432/hiair",
    )
    direct_database_url: str = os.getenv(
        "DIRECT_DATABASE_URL",
        os.getenv("DATABASE_URL", "postgresql://hiair:hiair@localhost:5432/hiair"),
    )
    jwt_secret: str = os.getenv("JWT_SECRET", "dev-only-change-me")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    access_token_ttl_minutes: int = int(os.getenv("ACCESS_TOKEN_TTL_MINUTES", "120"))
    refresh_token_ttl_days: int = int(os.getenv("REFRESH_TOKEN_TTL_DAYS", "30"))
    supabase_url: str = os.getenv("SUPABASE_URL", "").strip()
    supabase_anon_key: str = os.getenv("SUPABASE_ANON_KEY", "").strip()
    supabase_service_role_key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    supabase_jwt_secret: str = os.getenv("SUPABASE_JWT_SECRET", "").strip()
    hiair_auth_provider: str = os.getenv("HIAIR_AUTH_PROVIDER", "supabase").strip().lower()
    hiair_auth_legacy_enabled: bool = (
        os.getenv("HIAIR_AUTH_LEGACY_ENABLED", "false").strip().lower() == "true"
    )
    hiair_ios_url_scheme: str = os.getenv("HIAIR_IOS_URL_SCHEME", "hiair").strip()
    hiair_android_url_scheme: str = os.getenv("HIAIR_ANDROID_URL_SCHEME", "hiair").strip()
    hiair_auth_redirect_uri: str = os.getenv("HIAIR_AUTH_REDIRECT_URI", "hiair://auth/callback").strip()
    hiair_auth_email_bridge_enabled: bool = (
        os.getenv("HIAIR_AUTH_EMAIL_BRIDGE_ENABLED", "true").strip().lower() == "true"
    )
    allow_legacy_user_header_auth: bool = (
        os.getenv("ALLOW_LEGACY_USER_HEADER_AUTH", "false").strip().lower() == "true"
    )
    subscription_provider: str = os.getenv("SUBSCRIPTION_PROVIDER", "stub")
    subscription_webhook_secret: str = os.getenv("SUBSCRIPTION_WEBHOOK_SECRET", "")
    apple_store_verifier_mode: str = os.getenv("APPLE_STORE_VERIFIER_MODE", "stub")
    google_play_verifier_mode: str = os.getenv("GOOGLE_PLAY_VERIFIER_MODE", "stub")
    apple_bundle_id: str = os.getenv("APPLE_BUNDLE_ID", "com.hiair.app")
    apple_store_environment: str = os.getenv("APPLE_STORE_ENVIRONMENT", "sandbox")
    apple_app_apple_id: str = os.getenv("APPLE_APP_APPLE_ID", "").strip()
    google_play_package_name: str = os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair")
    weather_api_provider: str = os.getenv("WEATHER_API_PROVIDER", "openmeteo")
    weather_api_key: str = os.getenv("WEATHER_API_KEY", "")
    aqi_api_provider: str = os.getenv("AQI_API_PROVIDER", "openmeteo")
    aqi_api_key: str = os.getenv("AQI_API_KEY", "")
    pollen_smoke_primary_provider: str = os.getenv("POLLEN_SMOKE_PRIMARY_PROVIDER", "openmeteo_cams")
    pollen_smoke_secondary_provider: str = os.getenv("POLLEN_SMOKE_SECONDARY_PROVIDER", "")
    ambee_api_key: str = os.getenv("AMBEE_API_KEY", "")
    environment_cache_ttl_seconds: int = int(os.getenv("ENVIRONMENT_CACHE_TTL_SECONDS", "900"))
    # Protected envs default fail-closed (no synthetic sample air data).
    # Dev/test keep sample fallback unless explicitly disabled.
    environment_allow_sample_fallback: bool = (
        os.getenv(
            "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK",
            (
                "false"
                if os.getenv("APP_ENV", "development").strip().lower()
                in {"production", "prod", "staging"}
                else "true"
            ),
        )
        .strip()
        .lower()
        == "true"
    )
    openai_api_key: str = os.getenv("OPENAI_API_KEY", "")
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    openai_base_url: str = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1/chat/completions")
    openai_prompt_version: str = os.getenv("OPENAI_PROMPT_VERSION", "hiair-expl-v1")
    openai_rate_limit_per_minute: int = int(os.getenv("OPENAI_RATE_LIMIT_PER_MINUTE") or "60")
    openai_http_timeout_seconds: float = float(os.getenv("OPENAI_HTTP_TIMEOUT_SECONDS") or "8")
    openai_max_tokens: int = int(os.getenv("OPENAI_MAX_TOKENS") or "120")
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
    allow_insecure_local_dev: bool = (
        os.getenv("HIAIR_ALLOW_INSECURE_LOCAL_DEV", "false").strip().lower() == "true"
    )


settings = Settings()


def _is_protected_env(env_name: str) -> bool:
    return env_name.strip().lower() in {"production", "staging"}


def validate_runtime_settings(current: Settings) -> None:
    if _is_protected_env(current.app_env):
        jwt_secret = getattr(current, "jwt_secret", "")
        if not jwt_secret or jwt_secret == "dev-only-change-me":
            raise RuntimeError("JWT_SECRET must be explicitly configured in protected environments.")
        if getattr(current, "allow_legacy_user_header_auth", False):
            raise RuntimeError("Legacy X-User-Id auth must be disabled in protected environments.")
        if getattr(current, "allow_insecure_local_dev", False):
            raise RuntimeError("HIAIR_ALLOW_INSECURE_LOCAL_DEV must be disabled in protected environments.")
        if getattr(current, "hiair_auth_provider", "legacy") == "supabase" and not getattr(
            current, "supabase_url", ""
        ):
            raise RuntimeError("SUPABASE_URL must be configured when HIAIR_AUTH_PROVIDER=supabase.")
        apple_mode = getattr(current, "apple_store_verifier_mode", "stub").strip().lower()
        google_mode = getattr(current, "google_play_verifier_mode", "stub").strip().lower()
        if apple_mode == "stub":
            raise RuntimeError("APPLE_STORE_VERIFIER_MODE=stub is forbidden in protected environments.")
        if google_mode == "stub":
            raise RuntimeError("GOOGLE_PLAY_VERIFIER_MODE=stub is forbidden in protected environments.")
        if google_mode not in ("live", "disabled"):
            raise RuntimeError("GOOGLE_PLAY_VERIFIER_MODE must be live or disabled in protected environments.")
        if getattr(current, "subscription_provider", "stub").strip().lower() == "stub":
            raise RuntimeError("SUBSCRIPTION_PROVIDER=stub is forbidden in protected environments.")
