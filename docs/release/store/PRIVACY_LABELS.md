# Privacy Labels Draft

## Data Types
- Account identifiers: email, user id.
- User-provided wellness signals: symptoms, profile preferences.
- Environmental context: coordinates (currently user-entered in onboarding/settings flow).
- Device push identifiers: optional notification device token.

## Usage Purposes
- Core app functionality (risk/planner/insights).
- Personalization for recommendations and alert thresholds.
- Account security and session management.

## Data Controls
- Export endpoint: `GET /api/privacy/export`
- Delete endpoint: `POST /api/privacy/delete-account`
- Data retention policies documented in backend env + retention scripts.

## Not Collected
- No payment card data stored by app backend in current scaffold mode.
- No health diagnosis records from providers.

## External Blockers
- Final legal counsel review.
- Final platform form selection in App Store Connect / Play Console.
