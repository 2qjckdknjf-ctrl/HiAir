# Xcode Cloud release policy

**App:** HiAir (`com.hiair.app`, Apple ID `6773610034`)  
**Last updated:** 2026-08-29

This document is the repository policy after the 2026-08-29 incident: web/SEO/docs commits triggered Xcode Cloud **Archive** and App Store Connect delivery of a binary still stamped `CFBundleShortVersionString = 1.0.1` while the live store version is **1.1**.

Apple rejected those deliveries (`ITMS-90478`, `ITMS-90186`, `ITMS-90062`). The SEO diffs were not the version error. The architecture error was coupling ordinary git events to App Store distribution.

Git cannot edit App Store Connect workflow start conditions. This repo adds a fail-closed `ci_post_clone.sh` gate. An owner still must align the ASC workflow UI with the design below.

## Workflow A — iOS validation (no App Store upload)

| Item | Value |
|------|--------|
| Mechanism | GitHub Actions `.github/workflows/ios-ci.yml` |
| Purpose | Compile Debug + Release simulator, run `HiAirTests` |
| Triggers | `push` / `pull_request` **path-filtered** to `mobile/ios/**` |
| Distribution | None (`CODE_SIGNING_ALLOWED=NO`) |

This is the allowed automatic check for iOS source changes, including PRs.

## Workflow B — iOS release (Archive + App Store Connect)

| Item | Value |
|------|--------|
| Current ASC name | `HiAir TestFlight` (configured in App Store Connect / Xcode, not in git) |
| Purpose | Archive, sign, upload to App Store Connect |
| Allowed git starts (enforced in `ci_post_clone.sh`) | See **ARCHIVE_ALLOWED** below |
| Forbidden automatic starts | Any branch push, PR open/update, schedule, web/docs/SEO, `ci_scripts`-only |

### ARCHIVE_ALLOWED (exact rule in `ci_post_clone.sh`)

Archive/App Store delivery is allowed only when **all** of these are true:

1. **Release intent** (`explicit_ios_release_start`):
   - `CI_START_CONDITION` is `manual` or `manual_rebuild`, **or**
   - `CI_TAG` matches `ios-*`, `v[0-9]*`, or `release-*`, **or**
   - `CI_BRANCH` matches `release/*`
2. **iOS app source** changed in the commit/PR diff (`ios_app_source_gate.sh`). `web/`, `docs/`, and `mobile/ios/ci_scripts` alone do **not** count.
3. **Marketing version > live 1.1** (`stale_marketing_version` is false). Source: `MARKETING_VERSION` in `mobile/ios/project.yml` (that string is `CFBundleShortVersionString`). Rejected: `1.0`, `1.0.*`, `1.1`, `1.1.0`. `CFBundleVersion` / `CURRENT_PROJECT_VERSION` is not consulted.

Otherwise `ci_post_clone.sh` exits 1 and Xcode Cloud does not Archive.

Until the ASC UI is split, the **same** Xcode Cloud workflow may still *start* on web commits. The post-clone script then **exits 1** so Archive does not produce an upload. A red Xcode Cloud check on a web PR is expected and is **not** a GitHub required check.

### Owner action in App Store Connect (cannot be done from git)

1. **Files and Folders** custom condition: start only if `mobile/ios` changes (optional; the script already refuses web-only).
2. Restrict Branch Changes: do **not** use Any Branch for Archive.
3. Preferred split:
   - Validation workflow: Build + Test only, PRs / iOS branches, **no Archive**.
   - Release workflow: Archive + TestFlight Internal, **Manual** and/or tags `ios-*`, **no** production App Store auto-submit.
4. Do not attach a GitHub required status to the Archive workflow.

Apple-supported start conditions: Branch Changes, Pull Request Changes, Tag Changes, Schedule, Manual. Path filtering exists only as Files and Folders in the workflow UI, not as a GitHub Actions `paths:` block. `[ci skip]` in the latest commit message skips the build entirely.

## Version source of truth

| Key | Location | Value on `main` (2026-08-29) |
|-----|----------|------------------------------|
| `MARKETING_VERSION` | `mobile/ios/project.yml` → XcodeGen → `HiAir.xcodeproj` | `1.0.1` (**stale**) |
| `CFBundleShortVersionString` | `HiAir/Info.plist` = `$(MARKETING_VERSION)` | expands to `1.0.1` |
| `CURRENT_PROJECT_VERSION` | `project.yml` | `215` |
| `CFBundleVersion` | `Info.plist` = `$(CURRENT_PROJECT_VERSION)` | expands to `215` unless Xcode Cloud overrides with `CI_BUILD_NUMBER` |
| Live App Store | iTunes lookup `id=6773610034` | **`1.1`** |

Build 267 reported `1.0.1` because the committed marketing version is `1.0.1`. App Store Connect build numbers (259–267) are not the repo `215`; raising `CFBundleVersion` alone does **not** fix `ITMS-90478`.

Do **not** bump `MARKETING_VERSION` on `main` merely so accidental uploads succeed. Fail-closed rejection is safer than a successful unintended `1.1.1` binary.

## Next intentional marketing version

Must be **greater than 1.1**. Project roadmap next train is **1.2** (`docs/roadmap/HIAIR_1_2_BEST_TIME_ACTIVITY_PLANNER.md`). Do not upload a binary until an owner intends that iOS release, with `MARKETING_VERSION` already set on a `release/*` branch or `ios-*` tag.

`ci_post_clone.sh` refuses Archive while marketing version is `1.0`, `1.0.*`, `1.1`, or `1.1.0`.

## Build-number policy

`CFBundleVersion` / `CURRENT_PROJECT_VERSION` must increase monotonically for each uploaded binary. That is necessary but **not sufficient**. The 2026-08-29 failures were marketing-version / closed pre-release train, not a duplicate build number.

## What may trigger distribution

| Change | GitHub iOS CI | Xcode Cloud Archive → ASC |
|--------|---------------|---------------------------|
| `web/`, docs, SEO, IndexNow | No (path filter) | Must not upload (script skip) |
| `mobile/ios/ci_scripts` only | Yes (paths include `mobile/ios/**`) | Must not upload |
| iOS app source on feature/`main` | Yes | Must not upload automatically |
| Explicit release (manual / `release/*` / `ios-*` tag) **and** marketing version > 1.1 | As applicable | Allowed |

## GitHub required checks

`main` has **no** classic branch protection and **no** rulesets (`GET .../branches/main/protection` → 404, `rulesets` → `[]`).

**`XCODE_CLOUD_REQUIRED_FOR_MAIN = NO`.** Required status checks: **none**. Rulesets: **none**.

Failed App Store delivery must not block web merges. Do not admin-bypass. Do not make Archive a required check.

## Related files

- `mobile/ios/ci_scripts/ci_post_clone.sh`
- `mobile/ios/ci_scripts/ios_app_source_gate.sh`
- `docs/release/XCODE_CLOUD_SETUP.md`
- `.github/workflows/ios-ci.yml`
