import argparse
import os
from dataclasses import dataclass

from dotenv import dotenv_values


@dataclass
class CheckResult:
    level: str
    message: str


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate security-related backend environment values.")
    parser.add_argument(
        "--env-file",
        default=".env",
        help="Path to .env file. Missing file is allowed; OS env vars are still used.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 when any warning/error is found.",
    )
    args = parser.parse_args()

    env = _load_env(args.env_file)
    results = _run_checks(env)

    warnings_or_errors = 0
    for item in results:
        print(f"[{item.level}] {item.message}")
        if item.level in ("WARN", "ERROR"):
            warnings_or_errors += 1

    if warnings_or_errors == 0:
        print("Environment security check passed.")
        return 0

    if args.strict:
        print("Environment security check failed in strict mode.")
        return 1

    print("Environment security check completed with warnings.")
    return 0


def _load_env(env_file: str) -> dict[str, str]:
    file_values = dotenv_values(env_file)
    combined: dict[str, str] = {}

    for key, value in file_values.items():
        if value is not None:
            combined[key] = value
    for key, value in os.environ.items():
        combined[key] = value
    return combined


def _run_checks(env: dict[str, str]) -> list[CheckResult]:
    checks: list[CheckResult] = []
    app_env = env.get("APP_ENV", "development").strip().lower()
    protected_env = app_env in {"production", "staging"}
    allow_insecure_local_dev = env.get("HIAIR_ALLOW_INSECURE_LOCAL_DEV", "false").strip().lower() == "true"

    jwt_secret = env.get("JWT_SECRET", "")
    if not jwt_secret:
        checks.append(CheckResult("ERROR", "JWT_SECRET is missing."))
    elif jwt_secret == "dev-only-change-me":
        checks.append(CheckResult("ERROR", "JWT_SECRET uses insecure default value."))
    elif len(jwt_secret) < 32:
        checks.append(CheckResult("WARN", "JWT_SECRET should be at least 32 bytes long."))
    else:
        checks.append(CheckResult("OK", "JWT_SECRET length and value look acceptable."))

    ttl_raw = env.get("ACCESS_TOKEN_TTL_MINUTES", "120")
    try:
        ttl = int(ttl_raw)
        if ttl < 15:
            checks.append(CheckResult("WARN", "ACCESS_TOKEN_TTL_MINUTES is very low (<15)."))
        elif ttl > 1440:
            checks.append(CheckResult("WARN", "ACCESS_TOKEN_TTL_MINUTES is high (>1440)."))
        else:
            checks.append(CheckResult("OK", "ACCESS_TOKEN_TTL_MINUTES is in expected range."))
    except ValueError:
        checks.append(CheckResult("ERROR", "ACCESS_TOKEN_TTL_MINUTES must be an integer."))

    admin_token = env.get("NOTIFICATION_ADMIN_TOKEN", "")
    if not admin_token:
        if protected_env and not allow_insecure_local_dev:
            checks.append(CheckResult("ERROR", "NOTIFICATION_ADMIN_TOKEN is empty in protected environment."))
        else:
            checks.append(CheckResult("WARN", "NOTIFICATION_ADMIN_TOKEN is empty. Admin endpoints may be unavailable."))
    elif len(admin_token) < 16:
        checks.append(CheckResult("WARN", "NOTIFICATION_ADMIN_TOKEN should be at least 16 chars."))
    else:
        checks.append(CheckResult("OK", "NOTIFICATION_ADMIN_TOKEN is present."))

    if protected_env and allow_insecure_local_dev:
        checks.append(CheckResult("ERROR", "HIAIR_ALLOW_INSECURE_LOCAL_DEV must be false in protected environments."))

    subscription_provider = env.get("SUBSCRIPTION_PROVIDER", "stub").strip().lower()
    if subscription_provider not in ("stub", "stripe", "apple", "google"):
        checks.append(
            CheckResult(
                "ERROR",
                "SUBSCRIPTION_PROVIDER must be one of: stub, stripe, apple, google.",
            )
        )
    else:
        checks.append(CheckResult("OK", f"SUBSCRIPTION_PROVIDER={subscription_provider}."))

    apple_mode = env.get("APPLE_STORE_VERIFIER_MODE", "stub").strip().lower()
    apple_env = env.get("APPLE_STORE_ENVIRONMENT", "sandbox").strip().lower()
    apple_app_id = env.get("APPLE_APP_APPLE_ID", "").strip()
    if apple_mode not in ("stub", "live"):
        checks.append(CheckResult("ERROR", "APPLE_STORE_VERIFIER_MODE must be stub or live."))
    elif protected_env and apple_mode == "stub":
        checks.append(
            CheckResult(
                "ERROR",
                "APPLE_STORE_VERIFIER_MODE=stub is forbidden in production/staging.",
            )
        )
    elif apple_mode == "live":
        if apple_env not in ("sandbox", "production", "prod", "xcode", "localtesting", "local_testing", "local"):
            checks.append(
                CheckResult(
                    "ERROR",
                    "APPLE_STORE_ENVIRONMENT must be sandbox, production, xcode, or localtesting.",
                )
            )
        if protected_env and apple_env not in ("production", "prod"):
            checks.append(
                CheckResult(
                    "ERROR",
                    "APPLE_STORE_ENVIRONMENT must be production in protected environments.",
                )
            )
        if apple_env in ("production", "prod"):
            if not apple_app_id:
                checks.append(
                    CheckResult("ERROR", "APPLE_APP_APPLE_ID is required for production Apple verification.")
                )
            elif not apple_app_id.isdigit():
                checks.append(CheckResult("ERROR", "APPLE_APP_APPLE_ID must be numeric."))
        # API credentials are optional for JWS verify (root certs + SignedDataVerifier);
        # issuer/key are used for App Store Server API history calls when configured.
        for key in ("APPLE_ISSUER_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY"):
            if protected_env and not env.get(key, "").strip():
                checks.append(
                    CheckResult(
                        "OK",
                        f"{key} unset (optional; JWS verify does not require App Store Server API keys).",
                    )
                )
        checks.append(CheckResult("OK", f"APPLE_STORE_VERIFIER_MODE=live env={apple_env}."))
    else:
        checks.append(CheckResult("OK", f"APPLE_STORE_VERIFIER_MODE={apple_mode}."))

    google_mode = env.get("GOOGLE_PLAY_VERIFIER_MODE", "stub").strip().lower()
    google_package = env.get("GOOGLE_PLAY_PACKAGE_NAME", "com.hiair").strip()
    if google_mode not in ("stub", "live", "disabled"):
        checks.append(CheckResult("ERROR", "GOOGLE_PLAY_VERIFIER_MODE must be stub, live, or disabled."))
    elif protected_env and google_mode == "stub":
        checks.append(
            CheckResult(
                "ERROR",
                "GOOGLE_PLAY_VERIFIER_MODE=stub is forbidden in production/staging.",
            )
        )
    elif google_mode == "disabled":
        # Intentional iOS-first production posture — OK for --strict (not a WARN).
        checks.append(
            CheckResult(
                "OK",
                "GOOGLE_PLAY_VERIFIER_MODE=disabled — Android billing unavailable; "
                "not STORE SANDBOX READY; no service account required.",
            )
        )
    elif google_mode == "live":
        if protected_env and not google_package:
            checks.append(CheckResult("ERROR", "GOOGLE_PLAY_PACKAGE_NAME is required for live Google verification."))
        if not env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip():
            if protected_env:
                checks.append(
                    CheckResult(
                        "ERROR",
                        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is required when GOOGLE_PLAY_VERIFIER_MODE=live.",
                    )
                )
            else:
                checks.append(
                    CheckResult(
                        "WARN",
                        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON missing for live mode (required before Android verify).",
                    )
                )
        else:
            checks.append(CheckResult("OK", f"GOOGLE_PLAY_VERIFIER_MODE=live package={google_package or 'unset'}."))
    else:
        checks.append(CheckResult("OK", f"GOOGLE_PLAY_VERIFIER_MODE={google_mode}."))

    webhook_secret = env.get("SUBSCRIPTION_WEBHOOK_SECRET", "")
    if subscription_provider != "stub":
        if not webhook_secret:
            checks.append(CheckResult("ERROR", "SUBSCRIPTION_WEBHOOK_SECRET is required for non-stub provider."))
        elif len(webhook_secret) < 16:
            checks.append(CheckResult("WARN", "SUBSCRIPTION_WEBHOOK_SECRET should be at least 16 chars."))
        else:
            checks.append(CheckResult("OK", "SUBSCRIPTION_WEBHOOK_SECRET is present."))
    elif webhook_secret:
        checks.append(CheckResult("OK", "SUBSCRIPTION_WEBHOOK_SECRET is set (stub mode currently)."))
    else:
        checks.append(CheckResult("WARN", "SUBSCRIPTION_WEBHOOK_SECRET is empty (acceptable for local stub mode)."))

    notifications_mode = env.get("NOTIFICATIONS_PROVIDER_MODE", "stub").strip().lower()
    if notifications_mode not in ("stub", "live"):
        checks.append(CheckResult("ERROR", "NOTIFICATIONS_PROVIDER_MODE must be stub or live."))
    elif notifications_mode == "stub":
        checks.append(CheckResult("OK", "NOTIFICATIONS_PROVIDER_MODE=stub."))
    else:
        has_fcm_legacy = bool(env.get("FCM_SERVER_KEY", ""))
        has_fcm_v1 = bool(env.get("FCM_PROJECT_ID", "") and env.get("FCM_CLIENT_EMAIL", "") and env.get("FCM_PRIVATE_KEY", ""))
        has_apns_static = bool(env.get("APNS_AUTH_TOKEN", "") and env.get("APNS_TOPIC", ""))
        has_apns_jwt = bool(
            env.get("APNS_TEAM_ID", "")
            and env.get("APNS_KEY_ID", "")
            and env.get("APNS_PRIVATE_KEY", "")
            and env.get("APNS_TOPIC", "")
        )
        if has_fcm_legacy or has_fcm_v1 or has_apns_static or has_apns_jwt:
            checks.append(CheckResult("OK", "NOTIFICATIONS_PROVIDER_MODE=live with provider credentials present."))
        else:
            checks.append(CheckResult("ERROR", "NOTIFICATIONS_PROVIDER_MODE=live but no provider credentials were found."))

    _check_positive_int(env, checks, "RETENTION_NOTIFICATION_DELIVERY_ATTEMPTS_DAYS")
    _check_positive_int(env, checks, "RETENTION_NOTIFICATION_EVENTS_DAYS")
    _check_positive_int(env, checks, "RETENTION_SUBSCRIPTION_WEBHOOK_EVENTS_DAYS")
    _check_positive_int(env, checks, "RETENTION_SECRET_ROTATION_EVENTS_DAYS")

    openai_key = env.get("OPENAI_API_KEY", "").strip()
    if protected_env and not openai_key:
        checks.append(
            CheckResult(
                "WARN",
                "OPENAI_API_KEY is empty in protected environment; AI explanations will use template fallback.",
            )
        )
    elif openai_key:
        checks.append(CheckResult("OK", "OPENAI_API_KEY is configured."))

    sample_fallback_raw = env.get("ENVIRONMENT_ALLOW_SAMPLE_FALLBACK", "").strip().lower()
    if protected_env:
        # Missing key defaults fail-closed in settings.py for protected APP_ENV.
        if sample_fallback_raw in ("true", "1", "yes"):
            checks.append(
                CheckResult(
                    "ERROR",
                    "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=true is forbidden in production/staging.",
                )
            )
        else:
            checks.append(
                CheckResult(
                    "OK",
                    "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK disabled for protected environment.",
                )
            )
    elif sample_fallback_raw in ("false", "0", "no"):
        checks.append(CheckResult("OK", "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=false."))
    else:
        checks.append(
            CheckResult(
                "OK",
                "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK allowed for non-protected environment.",
            )
        )

    return checks


def _check_positive_int(env: dict[str, str], checks: list[CheckResult], key: str) -> None:
    raw = env.get(key)
    if raw is None or raw == "":
        checks.append(CheckResult("WARN", f"{key} is not set; default retention value will be used."))
        return
    try:
        value = int(raw)
    except ValueError:
        checks.append(CheckResult("ERROR", f"{key} must be an integer."))
        return
    if value < 1:
        checks.append(CheckResult("ERROR", f"{key} must be >= 1."))
        return
    checks.append(CheckResult("OK", f"{key}={value}."))


if __name__ == "__main__":
    raise SystemExit(main())
