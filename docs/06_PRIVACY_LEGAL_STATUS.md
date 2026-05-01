# 06 Privacy Legal Status

## Privacy Features in Code
- Data export endpoint implemented.
- Account delete endpoint implemented.
- Retention cleanup scripts present for notification/subscription event families.
- Export now includes auth refresh token lifecycle records (`auth_refresh_tokens`) for the requesting user.
- Privacy API regression coverage includes export success/not-found and delete confirmation/not-found/success paths.

## Legal Positioning
- Wellness-only positioning documented.
- Non-diagnostic / no-treatment language present in drafts.
- Emergency disclaimer wording present in legal drafts.

## Status
- Engineering: DONE (backend + mobile privacy export/delete flows implemented and validated by gate).
- GDPR technical controls: DONE (data access/export/delete coverage and API regressions are in place).
- Privacy Policy status: BLOCKED (legal owner review + public URL publication required).
- Terms status: BLOCKED (legal owner review + public URL publication required).
- Legal: BLOCKED-EXTERNAL (requires legal owner review and publication of final policies/terms URLs).
