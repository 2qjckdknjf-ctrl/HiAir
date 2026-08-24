# Store-Ready Hardening Status — 2026-08-24

**Verdict:** `NO-GO / HARDENING IN PROGRESS`  
**Branch:** `cursor/store-ready-hardening-2026-08-22`  
**HEAD:** `09b7823e` (pre-truth-doc commit; see RC manifest after doc commit)  
**RC source SHA:** set only when `source_tree_reproducible=true` (tracked clean, no untracked source inputs)

## Closed this sprint

- **Provenance contract:** `manifest_generated_from_sha`, `manifest_file_sha256`, `.sha256` sidecar; `manifest_containing_commit_sha` documented as external-only; clean-tree fields (`tracked_worktree_clean`, `untracked_source_inputs`, `untracked_evidence_outputs`, `source_tree_reproducible`)
- **iOS capture pipeline:** UDID-resolved destinations, observed-environment gating, matrix runner, state screenshot tests
- **iOS visual:** softer tab-bar fade; paywall atmospheric background restored; service-period copy
- **iOS matrix:** iPhone 16e/17 Pro EN/RU, iPad Pro 13 EN/RU, a11y3/5, Reduce Motion/Transparency, dashboard state cells
- **Android:** DEBUG store-shot mock seed, phone/tablet 8-screen adb pipeline, glass dashboard cards + nav blur
- **Gates:** backend pytest, iOS 213 unit + full UI suite, Release verify (WARN operator l10n strings), Android lint/test/bundle

## Remaining before STORE SANDBOX READY

- Physical-device ASC Sandbox IAP (external)
- Production signing + ASC/Play upload/submit (external)
- Production deploy/secrets rotation (external)
- Android Deep Glass full renderer parity + RU tablet/locale matrix captures (local, PENDING)
- Manual TalkBack / VoiceOver walk (local, PENDING)
- Fresh canonical visual comparison sign-off after tab/paywall fixes (local)

## Not external blockers

Android parity screenshots, simulator matrix, and provenance tooling — **local work**, not owner blockers.

## Owner actions

1. Review `.evidence/ios-screenshots/2026-08-24-matrix-*` and Android `.evidence/android-screenshots/*`
2. Physical Sandbox IAP on device when ready
3. Explicit «можно сабмитить» before ASC/Play submit
