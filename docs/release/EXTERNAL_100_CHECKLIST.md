# External 100% Closure Checklist

Use this checklist to close the remaining **external** launch blockers after engineering is complete.

## 1) Fill production credentials

- [ ] `APPLE_TEAM_ID`
- [ ] `APP_STORE_CONNECT_APP_ID`
- [ ] `APP_REVIEW_TEST_EMAIL`
- [ ] `APP_REVIEW_TEST_PASSWORD`
- [ ] `GOOGLE_PLAY_PACKAGE_NAME`
- [ ] `PLAY_REVIEW_TEST_EMAIL`
- [ ] `PLAY_REVIEW_TEST_PASSWORD`
- [ ] `APNS_KEY_ID`
- [ ] `APNS_TEAM_ID`
- [ ] `APNS_KEY_PATH` (file exists and is readable)
- [ ] `FCM_PROJECT_ID`
- [ ] `FCM_SERVICE_ACCOUNT_JSON` (file exists and is readable)
- [ ] `LEGAL_PRIVACY_POLICY_URL` (public URL)
- [ ] `LEGAL_TERMS_URL` (public URL)

Populate them in `backend/.env.local` (or runtime env).
Template is available in `backend/.env.external.example`.

## 2) Real-device QA evidence

- [ ] Create `docs/release/qa/REAL_DEVICE_QA_REPORT.md` with:
  - tested device matrix (iOS + Android),
  - app versions/build numbers,
  - pass/fail per critical flow,
  - open issues with owner and ETA.

## 3) Store consoles

- [ ] App Store Connect listing metadata finalized and review account verified.
- [ ] Google Play listing + Data Safety + policy forms finalized.
- [ ] Closed beta tracks configured and reviewers can authenticate.

## 4) Final legal sign-off

- [ ] Legal owner approves Privacy Policy wording.
- [ ] Legal owner approves Terms wording.
- [ ] Reviewer notes contain wellness/non-medical disclaimer.
- [ ] Emergency disclaimer wording is present and approved.

## 5) Verification commands

Non-strict (informational):

`python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`

Strict (must pass for external closure):

`python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`

Full gate including strict external checks:

`scripts/release/hiair_final_gate.sh --strict-external`

## Status Vocabulary

- `DONE`: fully completed with evidence/artifact.
- `MISSING`: not provided or placeholder.
- `BLOCKED`: requires third-party access or owner action.
