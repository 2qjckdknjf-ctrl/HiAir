# HiAir backend agent alignment

This file supplements root `/AGENTS.md` for work under `backend/`.

Before AI/forecast/risk/planner/recommendation changes, read `/docs/roadmap/HIAIR_AI_DEVELOPMENT_ALIGNMENT.md`.

Rules:
- `HIAIR-SEC-000` is the immediate P0 blocker: close the dependency audit in a focused compatibility/security slice before later AI work.
- Then `HIAIR-REL-001` release/trust work remains P0; do not widen scope to voice/multi-agent features before that gate.
- For dependency remediation, preserve fail-closed App Store/Google Play verification and run verifier tests + full backend gate + `pip-audit`; do not blindly loosen security pins.
- Reuse existing `forecast`, `air_environment_service`, `air_score`, planner, recommendation and AI explanation services before adding new engines.
- Unavailable environmental inputs remain unavailable/null; never zero-fill or fabricate them.
- Keep health/wellness guardrails, consent and fail-closed subscription/auth boundaries from root `AGENTS.md`.
- Evidence/source/freshness must be preserved for predictive recommendations.
- Grow OS/ROMA own cross-project agent governance; do not create a second control plane in HiAir.
- Work one dependency-satisfied `HIAIR-*` task at a time and stop at its gate.