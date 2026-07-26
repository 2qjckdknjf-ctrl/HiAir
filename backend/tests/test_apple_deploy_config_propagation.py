"""Static checks that Apple production config propagates into deploy allowlists."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_check_env_security():
    path = BACKEND / "scripts" / "check_env_security.py"
    spec = importlib.util.spec_from_file_location("check_env_security", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


REQUIRED_KEYS = ("APPLE_STORE_ENVIRONMENT", "APPLE_APP_APPLE_ID")


@pytest.mark.parametrize(
    "rel",
    [
        ".env.example",
        "scripts/ops/deploy_hiair_api_cloudflare.sh",
        "infra/cloudflare/hiair-api/src/index.js",
        ".github/workflows/backend-deploy-production.yml",
        ".github/workflows/hiair-api-cloudflare.yml",
    ],
)
def test_apple_env_keys_present_in_deploy_surfaces(rel: str) -> None:
    text = _read(rel)
    for key in REQUIRED_KEYS:
        assert key in text, f"{key} missing from {rel}"


def test_cloudflare_worker_forwards_apple_env_keys() -> None:
    text = _read("infra/cloudflare/hiair-api/src/index.js")
    assert "APPLE_STORE_ENVIRONMENT" in text
    assert "APPLE_APP_APPLE_ID" in text
    assert "CONTAINER_ENV_KEYS" in text


def test_deploy_script_rejects_production_stub_and_redacts_secret_values() -> None:
    text = _read("scripts/ops/deploy_hiair_api_cloudflare.sh")
    assert "APPLE_STORE_VERIFIER_MODE=live" in text
    assert "APPLE_STORE_ENVIRONMENT=production" in text
    assert "numeric APPLE_APP_APPLE_ID" in text
    assert "GOOGLE_PLAY_VERIFIER_MODE=live or disabled" in text
    assert "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" in text
    assert "when GOOGLE_PLAY_VERIFIER_MODE=live" in text
    assert "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK" in text
    assert 'values["ENVIRONMENT_ALLOW_SAMPLE_FALLBACK"] = "false"' in text
    assert "file=sys.stderr" in text
    assert 'print(f"{key}={values[key]}")' not in text


def test_cloudflare_worker_forwards_google_and_sample_env_keys() -> None:
    text = _read("infra/cloudflare/hiair-api/src/index.js")
    assert "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" in text
    assert "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK" in text


@pytest.mark.parametrize(
    "rel",
    [
        ".github/workflows/backend-deploy-production.yml",
        ".github/workflows/hiair-api-cloudflare.yml",
    ],
)
def test_github_deploy_workflows_sync_google_sa_and_forbid_sample(rel: str) -> None:
    text = _read(rel)
    assert "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" in text
    assert "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK" in text
    assert "GOOGLE_PLAY_VERIFIER_MODE=live or disabled" in text
    assert "when GOOGLE_PLAY_VERIFIER_MODE=live" in text
    assert 'ENVIRONMENT_ALLOW_SAMPLE_FALLBACK"] = "false"' in text or (
        'ENVIRONMENT_ALLOW_SAMPLE_FALLBACK": "false"' in text
    )
    assert "HIAIR_AUTH_PROVIDER" in text
    assert "SUBSCRIPTION_PROVIDER != stub" in text


def test_deploy_backend_skips_stub_smoke_in_protected_envs() -> None:
    text = _read("scripts/release/deploy_backend.sh")
    assert "check_env_security.py --strict" in text
    assert "smoke_db_flow.py" in text
    assert "skipping stub DB smoke against protected environment" in text
    assert "post-deploy live smoke" in text
    assert "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=true" not in text


def test_cloudflare_workflow_maps_notification_admin_token() -> None:
    text = _read(".github/workflows/hiair-api-cloudflare.yml")
    assert "NOTIFICATION_ADMIN_TOKEN: ${{ secrets.NOTIFICATION_ADMIN_TOKEN }}" in text
    assert "post_deploy_api_smoke.py --require-live-ai" in text


def test_sync_script_contains_production_contract_keys() -> None:
    text = _read("scripts/release/sync_github_env_secrets.py")
    for key in (
        "HIAIR_AUTH_PROVIDER",
        "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK",
        "APPLE_STORE_VERIFIER_MODE",
        "APPLE_STORE_ENVIRONMENT",
        "APPLE_APP_APPLE_ID",
        "APPLE_BUNDLE_ID",
        "GOOGLE_PLAY_VERIFIER_MODE",
        "GOOGLE_PLAY_PACKAGE_NAME",
        "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
        "PRODUCTION_CONTRACT_KEYS",
    ):
        assert key in text
    assert "gh" in text
    assert "secret" in text
    assert "set" in text
    # Must not pass Authorization tokens via curl -H CLI args.
    assert 'Authorization: token' not in text
    assert "curl" not in text


def test_check_env_security_accepts_production_google_disabled() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "production",
            "APPLE_APP_APPLE_ID": "6773610034",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "apple",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "disabled",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "NOTIFICATION_ADMIN_TOKEN": "notification-admin-token-16",
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
            "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK": "false",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert errors == []
    oks = [item.message for item in results if item.level == "OK"]
    assert any("GOOGLE_PLAY_VERIFIER_MODE=disabled" in msg for msg in oks)


def test_check_env_security_rejects_production_sample_fallback() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "production",
            "APPLE_APP_APPLE_ID": "1234567890",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "apple",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "live",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": '{"client_email":"a@b.c","private_key":"k"}',
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
            "ENVIRONMENT_ALLOW_SAMPLE_FALLBACK": "true",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("ENVIRONMENT_ALLOW_SAMPLE_FALLBACK=true" in msg for msg in errors)


def test_check_env_security_rejects_production_stub() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "stub",
            "APPLE_STORE_ENVIRONMENT": "sandbox",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "stub",
            "GOOGLE_PLAY_VERIFIER_MODE": "live",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": '{"client_email":"a@b.c","private_key":"k"}',
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("APPLE_STORE_VERIFIER_MODE=stub" in msg for msg in errors)


def test_check_env_security_rejects_production_google_stub() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "production",
            "APPLE_APP_APPLE_ID": "1234567890",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "apple",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "stub",
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("GOOGLE_PLAY_VERIFIER_MODE=stub" in msg for msg in errors)


def test_check_env_security_rejects_non_production_apple_env_in_prod() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "sandbox",
            "APPLE_APP_APPLE_ID": "1234567890",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "apple",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "live",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": '{"client_email":"a@b.c","private_key":"k"}',
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("APPLE_STORE_ENVIRONMENT must be production" in msg for msg in errors)


def test_check_env_security_rejects_non_numeric_app_apple_id() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "production",
            "APPLE_APP_APPLE_ID": "not-a-number",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "apple",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "live",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": '{"client_email":"a@b.c","private_key":"k"}',
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("APPLE_APP_APPLE_ID must be numeric" in msg for msg in errors)


def test_check_env_security_rejects_live_google_without_service_account() -> None:
    module = _load_check_env_security()
    results = module._run_checks(
        {
            "APP_ENV": "production",
            "JWT_SECRET": "x" * 32,
            "DATABASE_URL": "postgresql://hiair:hiair@localhost:5432/hiair",
            "APPLE_STORE_VERIFIER_MODE": "live",
            "APPLE_STORE_ENVIRONMENT": "production",
            "APPLE_APP_APPLE_ID": "1234567890",
            "HIAIR_ALLOW_INSECURE_LOCAL_DEV": "false",
            "SUBSCRIPTION_PROVIDER": "google",
            "SUBSCRIPTION_WEBHOOK_SECRET": "webhook-secret-16+",
            "GOOGLE_PLAY_VERIFIER_MODE": "live",
            "GOOGLE_PLAY_PACKAGE_NAME": "com.hiair",
            "NOTIFICATIONS_PROVIDER_MODE": "stub",
        }
    )
    errors = [item.message for item in results if item.level == "ERROR"]
    assert any("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" in msg for msg in errors)
