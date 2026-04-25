# Security Audit

## Summary

No committed real secrets were confirmed in this pass; observed secret-like values are placeholders, CI test values, or local defaults. One protected-env ops gate issue was fixed. Public launch remains blocked by external secret governance and legal/ops signoff.

## Secrets scan

Findings included placeholder env values in `.env.example`, `backend/.env.staging.example`, CI test secrets, and documentation examples. No real credential value was copied into this report.

Status: PARTIAL

## Auth/JWT

JWT issuance/verification is implemented. Protected envs reject insecure JWT defaults. Strict env check passes when safe test env values are supplied.

Status: DONE

## Legacy auth

`X-User-Id` auth is disabled by default and rejected in protected envs. Test coverage confirms default rejection.

Status: DONE

## Admin endpoints

Ops endpoints now fail closed in protected envs if `NOTIFICATION_ADMIN_TOKEN` is absent. Local development can still run without token.

Status: FIXED

## Webhooks

Subscription webhook secret policy exists. Real provider verification is not E2E verified.

Status: PARTIAL

## Observability

Observability endpoints are admin-token gated. Metrics are in-process and not full production monitoring.

Status: PARTIAL

## Mobile security

iOS stores the bearer token in Keychain with one-time migration from `UserDefaults`. Android stores the bearer token encrypted with Android Keystore-backed AES/GCM and disables app backup.

Status: FIXED

## Privacy-sensitive endpoints

Privacy export/delete endpoints require auth.

Status: DONE

## Critical findings

| Finding | Status | Fix |
|---|---|---|
| Ops dependency allowed missing admin token in protected envs | FIXED | `require_ops_admin_token` now returns 503 in staging/production when token is unset |

## Fixes applied

- `backend/app/api/deps.py`: fail-closed protected-env ops token guard.
- `backend/tests/test_security_runtime_policies.py`: regression test.
- `backend/scripts/check_env_security.py`: warning text updated.
- `mobile/android/app/src/main/AndroidManifest.xml`: backup disabled.
- `mobile/ios/HiAir/KeychainStore.swift`: Keychain token storage.
- `mobile/android/app/src/main/java/com/hiair/SessionStore.kt`: Keystore-backed encrypted token storage.

## Remaining blockers

- BLOCKED_EXTERNAL: production secret manager and rotation evidence.
- BLOCKED_EXTERNAL: APNs/FCM credentials.
- BLOCKED_EXTERNAL: payment provider credentials if commercial billing is enabled.
- NEEDS_MANUAL_QA: secure token migration/logout behavior on physical devices.
- RISK: deployment-layer rate limits/WAF not proven.
