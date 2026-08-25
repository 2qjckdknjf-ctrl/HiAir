# 05 Release Readiness

**Status (2026-08-23):** `NO-GO / HARDENING IN PROGRESS` — see `docs/audit/STORE_READY_EXECUTION_2026-08-22.md`.

## Automated Gates (re-run 2026-08-23)
- Backend `pytest` (full): **PASS** — 74% coverage.
- Backend account-deletion + deploy SHA policy tests: **PASS**.
- Android `testDebugUnitTest` + `lintDebug` + `assembleRelease` + `bundleRelease` (API 36): **PASS**.
- iOS simulator build + `HiAirTests` + `HiAirUITests` (iPhone 17 Pro): **PASS** (prior session).
- iPad `IPadSandboxPurchaseUITests` (StoreKit Test harness): **PASS**.

## P0 Hardening (closed locally)
- Account deletion: Apple `authorization_code`, requirements endpoint, `operation_id` recovery UI (iOS/Android).
- `unknown` auth provider bypass: fail-closed redetect + regression test.
- Deploy SHA: `resolve_deploy_git_sha.py` authoritative; shell deploy script uses it before secret sync.

## Artifact provenance
- RC manifest: `docs/release/artifacts/rc-2026-08-22/MANIFEST.md` (`RC_SOURCE_SHA` vs `MANIFEST_COMMIT_SHA`).
- Generator: `scripts/release/generate_rc_artifact_manifest.sh`.

## Remaining local work
- Full screenshot matrix (iPad 13", a11y scales, Android phone/tablet).
- Deep Glass V4 Phase 4 (per-screen widgets/layout).
- iOS screen-by-screen accessibility/contrast audit completion.
- Docs truth-alignment across handoffs and operator runbooks.

## Remaining Manual / External
- App Store Connect metadata upload and review notes finalization.
- Google Play Console listing and data safety form finalization.
- Physical ASC Sandbox / Play License Tester IAP purchases.
- Signed IPA/AAB upload (no signing credentials in this worktree).
- Production deploy (explicitly forbidden this sprint).
- APNs/FCM production credential provisioning and live push verification.
- Final legal sign-off for Terms/Privacy wording.

## Closure Commands
- Informational: `python3 scripts/release/check_external_readiness.py --env-file backend/.env.local`
- Strict external check: `python3 scripts/release/check_external_readiness.py --strict --env-file backend/.env.local`
- Strict closure gate: `scripts/release/hiair_final_gate.sh --strict-external`
