# Mobile Observability Access Policy

Status: FIXED for closed-beta mobile clients.

## Decision

Backend `/api/observability/*` endpoints are internal ops endpoints. They require `X-Admin-Token` and must not be called from user-facing iOS or Android screens.

## Rationale

- The endpoints expose operational and AI-provider telemetry, not user-owned app data.
- Mobile users authenticate with bearer tokens, not admin tokens.
- Shipping these calls in Settings would create broken UX and increase the chance of accidentally exposing admin telemetry.

## Phase 2 implementation

- iOS removed direct API client methods for AI observability endpoints and removed the Settings observability card from the user-facing screen.
- Android removed direct API client methods for AI observability endpoints and removed the Settings observability card from the user-facing screen.

## Future user-safe option

If product needs user-visible AI transparency, add a separate bearer-authenticated endpoint that returns only user-owned, non-sensitive summaries. Do not reuse `/api/observability/*`.

## Verification

- `rg "/observability" mobile/ios mobile/android` should return no mobile client endpoint usage.
- Backend observability remains ops-gated.
