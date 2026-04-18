# GDPR/CCPA and Wellness Positioning Review

Date: 2026-04-07  
Status: backend baseline implemented; legal final review still required

## Scope reviewed

- Account/auth data (`users`)
- Profile and wellness logs (`profiles`, `symptom_logs`, `risk_scores`)
- Notifications data (`push_device_tokens`, `notification_events`, `notification_delivery_attempts`)
- Subscription data (`user_subscriptions`, webhook audit)
- Operational logging and observability endpoints

## Implemented technical controls

- Authenticated access boundaries for user data paths (`Bearer` + user existence check).
- Profile ownership checks to prevent cross-user access by `profile_id`.
- Subscription gating for premium recommendation endpoint.
- User data export endpoint:
  - `GET /api/privacy/export`
- Account deletion endpoint:
  - `POST /api/privacy/delete-account` with explicit `DELETE` confirmation.
- Webhook idempotency and audit trail (`subscription_webhook_events`).
- Environment security checks for release readiness:
  - `backend/scripts/check_env_security.py`
- Operational retention cleanup automation:
  - `backend/scripts/retention_cleanup.py` (dry-run and apply modes)

## Wellness positioning controls in product text

- Privacy draft states wellness-only scope and non-diagnostic purpose.
- Terms draft includes explicit non-medical disclaimer and emergency guidance.

## Remaining non-code obligations (legal/ops)

- Legal review of Privacy Policy and Terms text by target jurisdiction.
- Publish controller/contact details and formal DSAR process contact.
- Finalize retention schedule by table/log type and enforce deletion windows.
- Confirm child/guardian consent flows where applicable by market.
- Ensure production secrets policy (rotation cadence, vault ownership, audit).

## Current readiness assessment

- Engineering baseline for GDPR/CCPA-style access/deletion/export rights: **present**.
- Legal compliance sign-off and policy finalization: **pending**.
