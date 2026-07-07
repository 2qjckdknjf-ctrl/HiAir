# HiAir Beta Readiness Checklist

This checklist is used to prepare a closed beta on iOS and Android.

## 0) RC-1 production backend (CLOSED 2026-07-07)

- backend live providers deployed: **YES** — `api.hiair.io` on commit `a2123fe` (GitHub Actions run `28367913518` re-run PASS after Cloudflare token refresh).
- production smoke: **PASS** — `/api/health` 200; `source=sample` 200; Castelldefels `environmental.source=live`.
- latency: `/api/health` warm ~0.3–0.8s post-deploy; cold start ~60s after container rollout.
- **RC-1 verdict: READY**

## 0.1) RC-2 device certification (2026-07-07)

- **Code blockers closed:** iOS/Android fake Barcelona/Alex/dashboard actions removed; iOS tests fixed.
- Android build (debug/release/lint/tests): **PASS** (arm64 JDK 17).
- iOS build + tests: **PASS** (4/4).
- Backend pytest: **PASS** (119).
- Android/iOS **physical device QA**: **BLOCKED** (iPhone offline, no adb). Use **release** builds for prod API.
- **RC-2 verdict: BLOCKED** (hardware session). **Code path: READY for owner device session.**

## 1) Environment and secrets

- [ ] `DATABASE_URL` points to staging database.
- [ ] `NOTIFICATIONS_PROVIDER_MODE` is set for beta strategy (`stub` or `live`).
- [ ] Secret source is configured:
  - [ ] `SECRET_SOURCE=env|file|http|vault`
  - [ ] required provider credentials are present.
- [ ] `NOTIFICATION_ADMIN_TOKEN` is set and stored securely.
- [ ] `SUBSCRIPTION_PROVIDER` is configured (`stub` for current beta stage).
- [ ] `SUBSCRIPTION_WEBHOOK_SECRET` is set if webhook endpoint is externally reachable.
- [ ] `JWT_SECRET` is set and not default (`>=32` bytes recommended).
- [ ] `/api/notifications/provider-health` reports expected provider availability.
- [ ] `/api/notifications/secret-store-health` has no active errors.
  - [ ] use `X-Admin-Token` when `NOTIFICATION_ADMIN_TOKEN` is configured.

## 2) Backend validation before beta

- [ ] Run schema bootstrap:
  - `python scripts/init_db.py`
  - includes migration `014_wearable_activity.sql`
- [ ] Run environment security checks:
  - `python scripts/check_env_security.py --strict`
- [ ] Run retention cleanup dry-run:
  - `python scripts/retention_cleanup.py --dry-run`
- [ ] Run smoke flow:
  - `python scripts/smoke_db_flow.py`
- [ ] Run historical validation:
  - `python scripts/validate_risk_historical.py`
- [ ] Confirm API health:
  - `/api/health` returns `ok`.
- [ ] Confirm observability:
  - `/api/observability/metrics` responds (with `X-Admin-Token` when configured).
- [ ] Confirm auth/subscription guardrails:
  - `scripts/beta_preflight.py` passes authenticated checks.

## 3) iOS beta readiness (TestFlight)

- [ ] Generate/open project from `mobile/ios/project.yml`.
- [ ] Build and run on simulator/device without crashes.
- [ ] Validate app flow:
  - [ ] onboarding
  - [ ] dashboard
  - [ ] planner
  - [ ] symptom log
  - [ ] settings sync
- [ ] Archive app in Xcode.
- [ ] Upload to App Store Connect.
- [ ] Configure TestFlight internal group and invite testers.
- [ ] Add release notes with known limitations.

## 4) Android beta readiness (Google Play Internal Test)

- [ ] Open `mobile/android` and sync Gradle.
- [ ] Build debug and release variants.
- [ ] Validate app flow:
  - [ ] signup/login with persisted session
  - [ ] dashboard refresh
  - [ ] planner refresh
  - [ ] symptom submit
  - [ ] settings load/save
  - [ ] subscription activate/cancel
- [ ] Generate signed artifact (AAB/APK per release policy).
- [ ] Upload to Google Play Internal Test track.
- [ ] Add tester group and release notes.

## 4.1) Artifact manifest and evidence

- [ ] Run `python3 mobile/scripts/generate_release_manifest.py --strict`
- [ ] Attach `docs/release-artifacts-manifest.md` to release ticket/checklist.

## 5) Notifications and delivery checks

- [ ] Register at least one iOS and one Android device token.
- [ ] Trigger dispatch endpoint with high-risk message.
- [ ] Verify `/api/notifications/delivery-attempts` shows new attempts.
- [ ] Validate retry behavior on simulated transient errors (if possible).

## 6) Legal and product messaging

- [ ] Privacy policy reflects current data flows.
- [ ] Terms include wellness-only positioning (non-medical advice).
- [ ] In-app text does not imply diagnosis or treatment.

## 7) Go / No-Go criteria for closed beta

- [ ] Smoke and historical validation are green.
- [ ] No blocker issues in core flows.
- [ ] At least one full end-to-end notification dispatch path is verified.
- [ ] Team acknowledges known risks and follows mitigation notes.

## 8) Wearable & Activity (optional feature)

- [ ] Migration 014 applied on staging Supabase.
- [ ] `/api/v1/wearables/*` endpoints reachable with auth.
- [ ] iOS HealthKit usage string present; consent skippable.
- [ ] Android Health Connect dependency resolves; dashboard works without HC.
- [ ] `docs/qa-wearable-activity-checklist.md` spot-checked on at least one iOS and one Android device.
