# Privacy / GDPR Audit

## Summary

Engineering support for export/delete and retention cleanup exists. Legal documents are drafts and cannot be treated as approved. Store privacy metadata is drafted but incomplete.

## Engineering implemented

| Item | Status | Evidence |
|---|---|---|
| Authenticated data export | DONE | `GET /api/privacy/export` |
| Authenticated account deletion | DONE | `POST /api/privacy/delete-account` |
| Retention cleanup script | PARTIAL | Script exists; local dry-run blocked by DB |
| Residual data smoke assertions | PARTIAL | Present in script; not run locally due DB |
| Notification delivery logs | PARTIAL | Backend model/repository exists |

## Legal text drafted

- `docs/privacy-policy-draft.md`
- `docs/terms-of-service-draft.md`
- `docs/gdpr-ccpa-wellness-review.md`

Status: PARTIAL

## Legal signoff missing

- LEGAL_SIGNOFF_REQUIRED: Privacy Policy final approval.
- LEGAL_SIGNOFF_REQUIRED: Terms final approval.
- LEGAL_SIGNOFF_REQUIRED: GDPR controller/contact and DSAR channel.
- LEGAL_SIGNOFF_REQUIRED: child/guardian consent handling before broad release.

## Store privacy metadata missing

`docs/store-metadata-packet.md` contains draft data categories but still has unchecked items and `[TBD]` placeholders.

Status: MISSING

## External blockers

- BLOCKED_EXTERNAL: final public privacy URL.
- BLOCKED_EXTERNAL: support URL.
- BLOCKED_EXTERNAL: App Store privacy labels submission.
- BLOCKED_EXTERNAL: Google Play Data Safety submission.

## Fixes applied

No legal wording was finalized. Security docs and backend README were updated to align with current protected-env ops behavior.

## Remaining blockers

Public launch is NO-GO until legal signoff, final URLs, and store metadata submissions are complete.
