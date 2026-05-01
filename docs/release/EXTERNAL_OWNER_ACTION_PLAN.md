# External Owner Action Plan

- Generated at (UTC): `2026-05-01T12:38:50.186582+00:00`
- Source env file: `/Users/alex/Projects/HIAir/backend/.env.local`

## Current strict status
- `MISSING=14`
- `BLOCKED=2`

## Unresolved items
| Name | Status | Detail |
|---|---|---|
| `APPLE_TEAM_ID` | `MISSING` | APPLE_TEAM_ID is empty or placeholder |
| `APP_STORE_CONNECT_APP_ID` | `MISSING` | APP_STORE_CONNECT_APP_ID is empty or placeholder |
| `APP_REVIEW_TEST_EMAIL` | `MISSING` | APP_REVIEW_TEST_EMAIL is empty or placeholder |
| `APP_REVIEW_TEST_PASSWORD` | `MISSING` | APP_REVIEW_TEST_PASSWORD is empty or placeholder |
| `GOOGLE_PLAY_PACKAGE_NAME` | `MISSING` | GOOGLE_PLAY_PACKAGE_NAME is empty or placeholder |
| `PLAY_REVIEW_TEST_EMAIL` | `MISSING` | PLAY_REVIEW_TEST_EMAIL is empty or placeholder |
| `PLAY_REVIEW_TEST_PASSWORD` | `MISSING` | PLAY_REVIEW_TEST_PASSWORD is empty or placeholder |
| `APNS_KEY_ID` | `MISSING` | APNS_KEY_ID is empty or placeholder |
| `APNS_TEAM_ID` | `MISSING` | APNS_TEAM_ID is empty or placeholder |
| `APNS_KEY_PATH` | `MISSING` | APNS_KEY_PATH path is empty or placeholder |
| `FCM_PROJECT_ID` | `MISSING` | FCM_PROJECT_ID is empty or placeholder |
| `FCM_SERVICE_ACCOUNT_JSON` | `MISSING` | FCM_SERVICE_ACCOUNT_JSON path is empty or placeholder |
| `LEGAL_PRIVACY_POLICY_URL` | `MISSING` | LEGAL_PRIVACY_POLICY_URL is empty or placeholder |
| `LEGAL_TERMS_URL` | `MISSING` | LEGAL_TERMS_URL is empty or placeholder |
| `LEGAL_PRIVACY_POLICY_STATUS_FINALIZATION` | `BLOCKED` | privacy policy status is not finalized (owner/legal action required) |
| `LEGAL_TERMS_STATUS_FINALIZATION` | `BLOCKED` | terms status is not finalized (owner/legal action required) |

## Required runtime env values
- `APPLE_TEAM_ID=<value>` # currently empty/placeholder
- `APP_STORE_CONNECT_APP_ID=<value>` # currently empty/placeholder
- `APP_REVIEW_TEST_EMAIL=<value>` # currently empty/placeholder
- `APP_REVIEW_TEST_PASSWORD=<value>` # currently empty/placeholder
- `GOOGLE_PLAY_PACKAGE_NAME=<value>` # currently empty/placeholder
- `PLAY_REVIEW_TEST_EMAIL=<value>` # currently empty/placeholder
- `PLAY_REVIEW_TEST_PASSWORD=<value>` # currently empty/placeholder
- `APNS_KEY_ID=<value>` # currently empty/placeholder
- `APNS_TEAM_ID=<value>` # currently empty/placeholder
- `APNS_KEY_PATH=<value>` # currently empty/placeholder
- `FCM_PROJECT_ID=<value>` # currently empty/placeholder
- `FCM_SERVICE_ACCOUNT_JSON=<value>` # currently empty/placeholder
- `LEGAL_PRIVACY_POLICY_URL=<value>` # currently empty/placeholder
- `LEGAL_TERMS_URL=<value>` # currently empty/placeholder

## Mandatory legal finalization
- Set in `docs/06_PRIVACY_LEGAL_STATUS.md`:
  - `Privacy Policy status: DONE`
  - `Terms status: DONE`
  - `Legal: DONE`

## Verification commands
- `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- `scripts/release/hiair_final_gate.sh --strict-external`

## Safety rules
- Do not commit `.env.local`.
- Do not commit APNS key files.
- Do not commit FCM service-account JSON.
- Do not commit review/test passwords.
