# Data Safety Draft

## Data Collected
- Account identifiers: email, user id.
- User-provided wellness inputs: symptom logs, profile preferences.
- Environmental context: location coordinates used for risk/planner calculations.
- Notification identifiers: device token (optional when push enabled).

## Data Usage
- Core app functionality (dashboard, planner, insights, briefings).
- Personalization of non-medical recommendations and alert thresholds.
- Security/session continuity for authenticated API access.

## Data Sharing / Selling
- No sale of personal data by current backend implementation.
- No ad-network profile selling behavior in current release scope.

## User Controls
- Export: `GET /api/privacy/export`
- Delete account/data: `POST /api/privacy/delete-account`
- Notification preference toggles in settings.

## External Finalization
- Final Play Console Data Safety form still requires owner/legal submission and confirmation.
