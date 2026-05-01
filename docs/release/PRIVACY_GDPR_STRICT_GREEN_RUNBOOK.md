# Privacy/GDPR Strict Green Runbook

## Goal
- Move Privacy/GDPR from technical-ready to strict-external green.
- Close only owner/legal/runtime blockers required by:
  - `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
  - `scripts/release/hiair_final_gate.sh --strict-external`

## Current Truth
- Engineering privacy controls are already DONE (export/delete + regressions).
- Strict check still fails on external owner/legal inputs:
  - Missing runtime credentials/URLs.
  - Legal statuses not finalized.

## Step 1 - Fill Runtime External Variables (Local/Runtime Only)
Fill `backend/.env.local` (or runtime env source). Do not commit secrets.

Required keys:
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_APP_ID`
- `APP_REVIEW_TEST_EMAIL`
- `APP_REVIEW_TEST_PASSWORD`
- `GOOGLE_PLAY_PACKAGE_NAME`
- `PLAY_REVIEW_TEST_EMAIL`
- `PLAY_REVIEW_TEST_PASSWORD`
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_KEY_PATH`
- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_JSON`
- `LEGAL_PRIVACY_POLICY_URL`
- `LEGAL_TERMS_URL`

Validation requirements:
- No placeholders or empty values.
- `APNS_KEY_PATH` points to readable file.
- `FCM_SERVICE_ACCOUNT_JSON` points to readable file.
- Legal URLs are public `https://` links.

## Step 2 - Finalize Legal Status in Docs
After legal sign-off and URL publication, update `docs/06_PRIVACY_LEGAL_STATUS.md`:

- `Privacy Policy status: DONE`
- `Terms status: DONE`
- `Legal: DONE`

Keep wording explicit and final (no "draft", "pending", "TBD").

## Step 3 - Run Verification Commands
Run in this exact order:

1) Non-strict visibility check:
- `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`

2) Strict external gate:
- `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`

3) Full release gate with strict external:
- `scripts/release/hiair_final_gate.sh --strict-external`

Expected final state:
- `MISSING=0`
- `BLOCKED=0`
- strict command exit code `0`
- full strict gate `PASS`

## Step 4 - Capture Evidence
When strict is green, record artifacts:
- command outputs
- timestamp
- owner who provided legal sign-off
- final policy URLs

Update:
- `docs/reports/HIAIR_100_PERCENT_CLOSURE_LIVELOG.md`
- `docs/reports/HIAIR_100_PERCENT_CLOSURE_REPORT.md`

## Safety Rules (Mandatory)
- Do not commit `.env.local`.
- Do not commit APNs key files.
- Do not commit FCM service-account JSON.
- Do not commit review/test passwords.
- Keep secrets only in runtime/local ignored env sources.
