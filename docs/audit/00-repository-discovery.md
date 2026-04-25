# Repository Discovery

Snapshot date: 2026-04-25

## Commands executed

| Command | Result | Status |
|---|---|---|
| `pwd` | `/Users/alex/Projects/HIAir` | DONE |
| `git status --short` | Dirty working tree with many pre-existing modified backend/docs files and generated Python cache files | DONE |
| `git branch --show-current` | `cursor/risk-alias-store-gates` | DONE |
| `git log --oneline -10` | latest commit `c09fd46 Add risk-alias deprecation controls and store packet gate.` | DONE |

## Repository root

`/Users/alex/Projects/HIAir`

## Applications found

| Area | Path | Found | Notes |
|---|---|---|---|
| Backend | `backend` | DONE | FastAPI app, SQL migrations, scripts, tests |
| iOS | `mobile/ios` | DONE | Xcode project plus XcodeGen `project.yml` |
| Android | `mobile/android` | DONE | Gradle single-module Android app |
| Docs | `docs` | DONE | Roadmap, MVP, release, QA, legal, operator docs |
| Scripts | `backend/scripts`, `mobile/scripts` | DONE | Backend gates and release manifest generation |
| CI | `.github/workflows` | DONE | Backend, Android, iOS, external blocker ops |

## Key files found

- Backend requirements: `backend/requirements.txt`
- Android Gradle: `mobile/android/settings.gradle.kts`, `mobile/android/build.gradle.kts`, `mobile/android/app/build.gradle.kts`
- Android wrapper: `mobile/android/gradlew`
- iOS project: `mobile/ios/HiAir.xcodeproj`
- iOS XcodeGen spec: `mobile/ios/project.yml`
- Release manifest script: `mobile/scripts/generate_release_manifest.py`

## Strategic documents found

- `docs/roadmap-from-pdf.md`
- `docs/mvp-spec.md`
- `docs/architecture.md`
- `docs/ai-mvp-architecture.md`
- `docs/_operator/execution-master-plan.md`
- `docs/_operator/global-audit-hiair.md`
- `docs/_operator/master-gap-report.md`
- `docs/_operator/readiness-scorecard.md`

## Release documents found

- `docs/beta-readiness-checklist.md`
- `docs/beta-execution-runbook.md`
- `docs/release-package-2026-04-07.md`
- `docs/release-artifacts-manifest.md`
- `docs/release-notes-template.md`
- `docs/store-upload-last-mile.md`
- `docs/store-metadata-packet.md`
- `docs/qa-checklist.md`
- `docs/qa-run-001-report.md` through `docs/qa-run-006-report.md`

## Legal/privacy documents found

- `docs/privacy-policy-draft.md`
- `docs/terms-of-service-draft.md`
- `docs/gdpr-ccpa-wellness-review.md`
- `docs/data-retention-matrix.md`
- `docs/ops-retention-runbook.md`

## Missing or incomplete expected parts

| Expected part | Status | Notes |
|---|---|---|
| Final App Store / Play account evidence | BLOCKED_EXTERNAL | Requires Apple Developer / Google Play access |
| Final legal signoff | LEGAL_SIGNOFF_REQUIRED | Privacy and terms are drafts |
| Production secrets | BLOCKED_EXTERNAL | Must not be committed; env placeholders only |
| APNs/FCM production credentials | BLOCKED_EXTERNAL | Backend supports live mode, mobile token flow incomplete |
| iOS signed archive / IPA verification | BLOCKED_EXTERNAL | Simulator build verified; store signing needs account/certs |
| DB-backed local smoke on this machine | BLOCKED_BY_ENV | Docker command unavailable and local Postgres not running |
