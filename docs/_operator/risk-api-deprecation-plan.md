# Risk API Deprecation Plan

## Scope

Legacy endpoints under `/api/risk/*` remain available only for transition compatibility.
Primary product flow is `/api/air/*` + `/api/dashboard/overview` + `/api/planner/daily`.

## Timeline

- **Now**: deprecation headers enabled on `/api/risk/estimate`, `/api/risk/history`, `/api/risk/thresholds`.
- **2026-08-31**: freeze any new client usage of `/api/risk/*`.
- **2026-12-31**: sunset date for legacy `/api/risk/*`.
- **Post-sunset**: remove router and alias-level normalization paths after client confirmation.

## Contract Guardrails

- Keep risk level normalization strict via `app/services/risk_level_contract.py`.
- Maintain parity regression tests for shared behavior in `backend/tests/test_api_surface_extended.py`.
- Reject new mobile/client code that adds `/api/risk/*` calls.

## Migration Owners

- Backend owner: remove legacy router after sunset.
- Mobile owners: ensure all calls are `/api/air/*` or dashboard/planner aggregates.
- Release owner: verify no active clients depend on `/api/risk/*` during go/no-go.
