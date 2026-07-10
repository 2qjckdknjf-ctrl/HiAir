# HiAir — Operator Handbook (First 10 Users)

**Updated:** 2026-07-10  
**Engineering status:** **Android signed AAB ready — Play upload blocked on owner Play Console setup**

## Mission #5 — Play Internal Upload (2026-07-10)

| Track | Status | Blocker |
|-------|--------|---------|
| TestFlight | **READY** | Build 65 VALID |
| Play Internal | **BLOCKED** | No `com.hiair` app in Play Console + no service account JSON |

```bash
export JAVA_HOME="/Users/alex/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home"
bash scripts/release/validate_signed_android_release.sh
bash scripts/release/upload_play_internal.sh   # after JSON + app created
```

See `docs/release/MISSION5_OPERATOR_CERTIFICATION.md`

## What engineering has closed

- Production API live with live → cached → sample environmental pipeline
- Privacy export without premium gate (GDPR baseline)
- Mobile production UI: no fake data paths
- Backend 119 tests, Android/iOS build+lint+tests PASS
- `scripts/release/hiair_final_gate.sh` PASS on arm64 Mac (`.venv312`)

## What requires the owner

### 1. Device QA (mandatory before first users)

Use **release** builds pointing at `https://api.hiair.io`.

| Step | Action |
|------|--------|
| Connect iPhone | USB/Wi‑Fi; Developer Mode; trust Mac |
| Connect Android | Install platform-tools (`adb`); USB debugging |
| Install | Release APK (signed) / TestFlight or USB Release |
| Execute matrix | See `docs/qa-checklist.md` and `docs/release/qa/REAL_DEVICE_QA_REPORT.md` |
| Record results | Update REAL_DEVICE_QA_REPORT → PASS rows |

### 2. TestFlight (iOS)

1. Xcode Archive (Release) or Xcode Cloud
2. `mobile/ios/scripts/upload_ipa_testflight_api.sh`
3. Add internal testers in App Store Connect
4. Verify: login, dashboard live data, HealthKit consent flow

### 3. Play Internal Testing (Android)

1. Configure signing keystore (not in repo)
2. `./gradlew :app:bundleRelease`
3. Upload AAB to Play Console → Internal testing
4. Verify release build uses production API

### 4. Sandbox IAP (honest ladder)

Status: **ARCHITECTURE READY** — not STORE SANDBOX READY until on-device purchase verified.

Products: `com.hiair.premium.monthly`, `com.hiair.premium.yearly`.

### 5. Push notifications

Wire device token registration + APNs/FCM production credentials (`APNS_*`, `FCM_*` in `.env.local`).

### 6. Ops hygiene (P1)

Replace wrangler OAuth token in GitHub `CLOUDFLARE_API_TOKEN` with long-lived Custom API Token.

## Quick validation commands

```bash
bash scripts/release/hiair_final_gate.sh
.venv312/bin/python scripts/release/post_deploy_api_smoke.py
python3 scripts/release/check_external_readiness.py --env-file backend/.env.local
```

Strict owner gate (after device QA):

```bash
python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local
bash scripts/release/hiair_final_gate.sh --strict-external
```

## Support contacts & docs

- Known gaps: `docs/08_KNOWN_GAPS.md`
- Beta checklist: `docs/beta-readiness-checklist.md`
- Store handoff: `docs/release/store/`
- External plan: `docs/release/EXTERNAL_OWNER_ACTION_PLAN.md`
