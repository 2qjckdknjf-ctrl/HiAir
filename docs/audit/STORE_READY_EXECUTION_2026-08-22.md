# Store-Ready Execution Report — 2026-08-22

**Worktree:** `/Users/alex/Projects/HIAir-store-ready`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**Status ladder:** **`NO-GO / HARDENING IN PROGRESS`**

---

## Executive verdict

| Verdict | Reason |
|---------|--------|
| **NO-GO / HARDENING IN PROGRESS** | P0 regressions (account deletion E2E, unknown provider, deploy SHA) closed with tests. Deep Glass V4 selectively integrated on iOS/Android tokens. Full iOS/Android simulator gates pass. Remaining: full screenshot matrix (iPad 13", a11y scales, Android), signed store artifacts, physical Sandbox IAP, production deploy, broader docs truth-alignment. |

---

## P0 closure

| ID | Area | Status |
|----|------|--------|
| P0.1 Account deletion Apple E2E | **CLOSED locally** — iOS reauth + `apple_authorization_code`, Android confirmation, `operation_id` recovery, requirements endpoint |
| P0.2 Unknown provider bypass | **CLOSED locally** — redetect + immutable confirmed provider regression test |
| P0.3 Deploy SHA policy | **CLOSED locally** — `RESOLVED_RELEASE_SHA` authoritative; mismatch fails deploy |
| P0 Migrations | **CLOSED locally** (prior commit) |
| P0 Artifact manifest | **IN PROGRESS** — false manifest removed; `generate_rc_artifact_manifest.sh` added; rebuild after RC commit |

---

## Local gates (re-run 2026-08-22 evening)

| Gate | Result |
|------|--------|
| Backend `pytest` (full, `.venv`) | **PASS** — 74% coverage |
| Android unit + lint + release AAB (API 36) | **PASS** |
| iOS `HiAirTests` + `HiAirUITests` (iPhone 17 Pro sim) | **PASS** |
| iPad `IPadSandboxPurchaseUITests` (iPad Air 11" M4 sim) | **PASS** — paywall UI + fullScreenCover + subscribe path (`UITEST_IAP_FORCE_SUCCESS` harness; ASC Sandbox on physical device remains external) |

---

## Deep Glass V4

| Item | Status |
|------|--------|
| Canonical doc | `docs/design/DEEP_GLASS_V4_CANONICAL.md` |
| iOS tokens + floating tab bar + glass surfaces | **Integrated** |
| Android design tokens | **Synced** |
| Full screen-by-screen contrast audit | **PARTIAL** |

---

## Still open

| Area | Status |
|------|--------|
| Full screenshot matrix (iPad 13", a11y3/5, Android phone/tablet) | **IN PROGRESS** — iPhone captures in `docs/brand/store-assets/asc-screenshots/captured-iphone/` |
| Signed iOS archive / Play upload | **EXTERNAL** |
| Physical Sandbox IAP | **EXTERNAL** |
| Production deploy | **EXTERNAL** (forbidden this sprint) |
| Docs truth-alignment (`README`, `05_RELEASE_READINESS`, handoffs) | **PARTIAL** |

---

## Build numbers

| Platform | RC value |
|----------|----------|
| iOS `CFBundleVersion` | **213** |
| Android `versionCode` | **189** (targetSdk **36**) |

---

## Screenshot policy

See [`docs/release/SCREENSHOT_POLICY.md`](../release/SCREENSHOT_POLICY.md).

---

## Artifact manifest process

```bash
# After clean commit:
RC_SOURCE_SHA=$(git rev-parse HEAD) \
  scripts/release/generate_rc_artifact_manifest.sh
```

Distinguishes `RC_SOURCE_SHA` vs `MANIFEST_COMMIT_SHA`; iOS `.app` zipped before SHA-256.
