# HiAir QA Run 005 Report

Date: 2026-04-07  
Scope: pre-upload artifact evidence automation

## What was added

- New script: `mobile/scripts/generate_release_manifest.py`
  - scans expected release artifacts,
  - computes size and SHA256,
  - writes `docs/release-artifacts-manifest.md`,
  - supports strict mode (`--strict`) for upload readiness checks.

## Documentation updates

- `docs/mobile-beta-build-commands.md` updated with manifest generation commands.
- `docs/store-upload-last-mile.md` updated with strict manifest step.
- `docs/beta-readiness-checklist.md` updated with artifact evidence section.

## Verification

Executed from repo root:

- `python3 mobile/scripts/generate_release_manifest.py` -> passed.
- `python3 mobile/scripts/generate_release_manifest.py --strict` -> passed.

Detected artifacts:
- Android AAB: present
- Android debug APK: present
- iOS xcarchive: present
- iOS IPA: not present (non-blocking for strict mode in current flow)

Manifest generated:
- `docs/release-artifacts-manifest.md`

## Current status

- Upload evidence preparation is now reproducible and auditable.
- Remaining step is manual store upload execution (requires Apple/Google access).
