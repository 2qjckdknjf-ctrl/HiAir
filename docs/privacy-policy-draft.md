# HiAir Privacy Policy (Draft)

This draft is for closed beta and must be reviewed by legal before public launch.

## 1. Scope

HiAir is a wellness assistant for heat and air quality awareness.
It does not provide medical diagnosis or treatment.

## 2. Data we collect

- Account data:
  - email
  - internal user id
- Profile data:
  - selected persona type
  - sensitivity settings
  - optional location coordinates
- App usage and wellness logs:
  - symptom logs entered by user
  - risk scores and recommendations history
  - AI explanation events and recommendation cards
  - alert decision and delivery-related event history
- Device and push data:
  - push notification device tokens
  - notification delivery attempt logs
- Operational telemetry:
  - request metadata (path, status, latency, request id)

## 3. Why we process data

- Generate personalized risk insights and recommendations.
- Deliver important wellness alerts.
- Maintain reliability, security, and abuse prevention.
- Improve product quality during beta testing.

## 4. Legal basis (GDPR-oriented draft)

- Consent for optional sensitive-like wellness inputs.
- Legitimate interest for service operation, security, and debugging.
- Contractual necessity for account and app functionality.

## 5. Data retention

- Beta data is retained only as long as needed for testing and support.
- Logs and analytics retention windows should be minimized.
- Users can request deletion of account-linked data.
- Some operational delivery logs may be retained in minimized/de-linked form for reliability analytics.

## 6. Data sharing

- Data is not sold.
- Limited sharing may occur with infrastructure and API providers
  under contractual safeguards and data processing terms.

## 7. International transfers

- If data is processed outside user region, appropriate safeguards
  (contractual and technical) must be applied.

## 8. Security controls

- Encrypted transport (HTTPS/TLS).
- Access controls and least privilege for secrets and systems.
- Secret rotation policy for push provider credentials.
- Audit trails for push delivery attempts and key rotation events.
- Administrative observability/provider health endpoints require admin token when configured.

## 9. User rights

Users may request:
- access to their data,
- correction,
- deletion,
- objection/restriction where applicable.

Current product support (backend):
- Authenticated data export endpoint: `GET /api/privacy/export`
- Authenticated account deletion endpoint: `POST /api/privacy/delete-account`
- Export currently includes profile/settings/subscription/device-token history and AI/risk/alert event surfaces linked to the account.

Contact channel for requests must be published before public beta.

## 10. Children

If child persona is used, guardian consent requirements must be reviewed
before expansion beyond limited beta.

## 11. Contact

Add official controller/contact details before release.

## 12. Changes

Policy updates must be versioned with effective date and changelog.
