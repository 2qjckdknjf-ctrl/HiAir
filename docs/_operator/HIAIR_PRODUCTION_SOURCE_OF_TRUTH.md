# HiAir Production Source of Truth

**Status:** PARTIAL / EXTERNAL_VERIFICATION_REQUIRED  
**Updated:** 2026-09-08  
**Working branch:** `codex/hiair-nextgen-phase0-action`

This document separates verified repository/store evidence from assumptions. `UNKNOWN` is intentional and must not be upgraded to PASS without direct evidence.

## 1. Repository governance

| Item | Current evidence | Status |
|---|---|---|
| Repository | `2qjckdknjf-ctrl/HiAir` | VERIFIED |
| GitHub default branch | `cursor/bootstrap-ci-and-tooling` | VERIFIED / GOVERNANCE_DRIFT |
| `main` | `23eeea664d210dc7f539f2a301dc54042d64e02f` | VERIFIED |
| `main` protection | unprotected in GitHub branch metadata | VERIFIED / RISK |
| Active upgrade base | `feat/hiair-1.2-best-time-planner` @ `c3730d988bdde2ba7771c4a20ee00a496a051b8b` | VERIFIED |
| Next-gen working branch | `codex/hiair-nextgen-phase0-action` | VERIFIED |

### Governance rule

Do not:

- change the repository default branch;
- force-update `main`;
- merge the divergent upgrade stack into `main`;
- enable/alter repository protection policy;

without explicit owner authorization and a release-baseline reconciliation.

The current default branch is not a safe proxy for production truth.

---

## 2. Production surface matrix

| Surface | Public/current version | Git SHA | Branch/source | Evidence quality | Status |
|---|---|---|---|---|---|
| iOS App Store | HiAir `1.1` | UNKNOWN | UNKNOWN | live App Store listing confirms version/features, but not commit provenance | PUBLIC_VERIFIED / SHA_UNKNOWN |
| iOS TestFlight | UNKNOWN | UNKNOWN | UNKNOWN | App Store listing does not prove current TestFlight build | EXTERNAL_VERIFICATION_REQUIRED |
| Android Google Play public | UNKNOWN | UNKNOWN | UNKNOWN | no public-console evidence captured in this audit | EXTERNAL_VERIFICATION_REQUIRED |
| Android internal/closed track | historical evidence exists in repository docs | UNKNOWN | UNKNOWN | repository documentation only; current console state not re-verified | EXTERNAL_VERIFICATION_REQUIRED |
| Backend API | `https://api.hiair.io` is canonical project endpoint | UNKNOWN | Cloudflare production path per project operator docs | endpoint ownership is documented; current deployed SHA not independently captured here | SHA_UNKNOWN |
| Marketing/legal web | `https://hiair.io` | UNKNOWN | Cloudflare Pages/Worker architecture per project docs | domain/project architecture documented; deployed SHA not captured here | SHA_UNKNOWN |

---

## 3. Live iOS evidence captured during Phase 0

The current public App Store listing confirms HiAir 1.1 is available and advertises:

- live AQI/heat plus pollen/smoke when data exists;
- honest hourly forecast with missing metrics remaining missing;
- activity best-time windows;
- Travel mode;
- Family risk overview;
- work-site heat estimates;
- optional Apple Health insights;
- Premium deeper insights.

This supports the conclusion that several items from the older 1.2–1.6 roadmap are already user-facing and therefore must not be reintroduced as if they were greenfield features.

The store listing does **not** establish the corresponding Git commit SHA.

---

## 4. Release provenance gap

A production release should be traceable as:

```text
store/runtime version
    -> build/version identifier
    -> Git commit SHA
    -> release branch/tag
    -> backend deployed SHA
    -> database migration state
```

That chain is not yet complete for the audited production surfaces.

### Required closure

For the next public release, create immutable release evidence containing at minimum:

```text
iOS version/build -> Git SHA
Android versionCode/versionName -> Git SHA
backend deployment -> Git SHA
web deployment -> Git SHA
DB migration head
release timestamp
```

Prefer machine-generated evidence from CI/deployment jobs over manually written prose.

---

## 5. Current engineering branch relationship

The next-generation branch is intentionally based on the active upgrade stack, not `main`.

Current relationship at the beginning of this Phase 0 work:

```text
feat/hiair-1.2-best-time-planner
    -> codex/hiair-nextgen-phase0-action
```

`main` and the active upgrade stack are historically diverged, so a later release integration requires an explicit reconciliation plan rather than a blind merge.

---

## 6. Source-of-truth hierarchy

When evidence conflicts, use:

1. public runtime/store/production response evidence;
2. deployment-system evidence tied to a SHA;
3. production/release code;
4. automated tests;
5. canonical operator/architecture docs;
6. roadmap docs;
7. marketing copy.

A newer document timestamp alone is not proof that its described code is deployed.

---

## 7. Current blockers

### P0/P1

- production iOS build -> Git SHA mapping is missing from captured evidence;
- production backend -> Git SHA mapping is missing from captured evidence;
- repository default-branch and `main` governance do not represent a clean canonical release line.

### P1

- current Android Play track/publication state requires direct console verification;
- migration-head production evidence must be attached to the next release closure.

---

## 8. Required next actions

1. capture App Store Connect build/version provenance and map public iOS 1.1 to Git SHA;
2. capture Cloudflare/API deployment provenance and map `api.hiair.io` to Git SHA + migration head;
3. reconcile the active upgrade stack with the intended canonical release branch before any merge toward `main`.
