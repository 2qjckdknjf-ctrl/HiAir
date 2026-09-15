# HiAir mobile agent alignment

This file supplements root `/AGENTS.md` for work under `mobile/`.

Before AI/voice/planner/recommendation UI changes, read `/docs/roadmap/HIAIR_AI_DEVELOPMENT_ALIGNMENT.md`.

Rules:
- HIAIR-REL-001 release/trust/device/store work remains P0.
- Mobile surfaces are thin clients over canonical backend risk/forecast/planner logic; do not fork a second risk engine into Swift/Kotlin.
- Do not add agent/voice UI before HIAIR-PRED-002 is proven unless explicitly scoped as a non-production spike.
- Missing data stays visibly unavailable; never present null/unavailable hazards as safe/zero.
- Preserve consent, HealthKit/Health Connect, privacy and wellness-only boundaries from root `AGENTS.md`.
- Keep iOS/Android changes additive and consistent with current master-upgrade sequencing.
- Work one dependency-satisfied `HIAIR-*` task at a time and stop at its gate.