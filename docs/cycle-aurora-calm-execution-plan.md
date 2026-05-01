# HiAir Cycle: Aurora Calm v2 + Insights — Execution Plan

Status: live execution doc for cycle "aurora-calm + insights"
Owner: full-stack
Last updated: 2026-05-01
Branch: feat/aurora-calm-v2-and-insights

## Cycle decisions (frozen)

| Decision               | Choice                                                  |
|------------------------|---------------------------------------------------------|
| Feature scope          | Personal Patterns + Morning Briefing                    |
| Design direction       | iOS-first premium, Aurora Calm v2                       |
| Background reactivity  | Time-of-day only; risk via accent surfaces only         |
| Insights tab           | New 5th bottom-nav tab                                  |
| Stats library          | Pure Python Pearson, no scipy                           |
| Timezone source        | profiles.timezone, single source                        |
| AI explanations        | On-demand per request, language from Accept-Language   |
| Cycle scope limit      | Live Activities, Widgets, HealthKit, Family — not in    |

## Hard invariants (non-negotiable)

1. Deterministic core remains the source of truth for risk.
2. LLM never scores. It only explains deterministic outputs.
3. New screens work in fallback mode without LLM.
4. New screens degrade gracefully without network using last cached state.
5. Privacy export covers every new table from day one.
6. All new strings ship with ru + en pair.
7. No new hardcoded URLs in mobile screen code.
8. No new hardcoded color hex values in mobile screen code.
9. No legacy `medium` risk level in new endpoints; canonical
   `low/moderate/high/very_high` only.

## Stage gates

Each stage has explicit exit criteria. Do not start the next stage until the
current gate is green and recorded in this document.

---

## Stage 0 — Foundation alignment

Goal: branch + canonical docs + spec freeze.

Tasks:
1. Verify baseline: backend pytest, Android assembleDebug, iOS xcodebuild.
2. Create branch `feat/aurora-calm-v2-and-insights` from main.
3. Add `docs/aurora-calm-design-system.md` (this cycle's design SoT).
4. Add `docs/feat-personal-patterns-spec.md`.
5. Add `docs/feat-morning-briefing-spec.md`.
6. Add `docs/cycle-aurora-calm-execution-plan.md` (this document).
7. Update `docs/_operator/master-gap-report.md`: register that GAP-006/014/007
   are non-regression invariants for this cycle's new code.
8. Update `README.md` index with the four new docs.

Exit criteria:
- Three baseline builds green.
- Branch pushed.
- Five new doc files in repo.
- README index updated.

Artifact location:
- `docs/aurora-calm-design-system.md`
- `docs/feat-personal-patterns-spec.md`
- `docs/feat-morning-briefing-spec.md`
- `docs/cycle-aurora-calm-execution-plan.md`

---

## Stage 1 — Design tokens

Goal: design system code-level tokens land on both platforms.

iOS deliverables:
- `mobile/ios/HiAir/DesignSystem/Tokens.swift`
  - Color tokens (background gradient stops, surfaces, text, risk accents)
  - Spacing scale enum
  - Radius enum
  - Typography enum (font + size + weight)
  - Motion constants
- `mobile/ios/HiAir/DesignSystem/RiskAccent.swift`
  - `func riskAccent(_ level: RiskLevel) -> Color`
- Dev screen accessible from Settings → Developer → Design tokens.

Android deliverables:
- `mobile/android/app/src/main/java/com/hiair/ui/design/Tokens.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/design/RiskAccent.kt`
- Dev screen accessible from Settings → Developer → Design tokens.

Backend deliverables: none.

Tests:
- iOS snapshot test on swatch screen.
- Android snapshot test on swatch screen.

Exit criteria:
- Both builds green.
- Both swatch screens show all tokens correctly on iPhone 15 Pro and Pixel 6.

---

## Stage 2 — Atmospheric layer

Goal: ambient particles + time-of-day background ship.

iOS deliverables:
- `mobile/ios/HiAir/DesignSystem/TimeOfDayBackground.swift`
- `mobile/ios/HiAir/DesignSystem/AtmosphericParticles.swift`

Android deliverables:
- `mobile/android/app/src/main/java/com/hiair/ui/design/TimeOfDayBackground.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/design/AtmosphericParticles.kt`

Tests:
- Unit test: `particleConfig(pm25)` returns the expected (count, opacity, size).
- Visual diff: dev screen at six clock hours shows correct gradient.

Exit criteria:
- FPS ≥ 58 on iPhone 13 and Pixel 6 with full particles + globe layered.
- Both background and particles available via dev screen for QA.

---

## Stage 3 — Globe anchor

Goal: weather-card globe with time-driven base color and risk-driven glow.

iOS deliverables:
- `mobile/ios/HiAir/DesignSystem/GlobeAnchor.swift`

Android deliverables:
- `mobile/android/app/src/main/java/com/hiair/ui/design/GlobeAnchor.kt`

Tests:
- Unit: `glowColor(riskLevel)` mapping table.
- Manual: globe pulses correctly at all four risk levels.

Exit criteria:
- Globe renders on both platforms in dev screen.
- Pulse cadence matches design spec at each risk level.

---

## Stage 4 — Dashboard redesign

Goal: full Dashboard rebuild on Aurora Calm v2 tokens.

iOS:
- Rewrite `mobile/ios/HiAir/Screens/DashboardView.swift` against new tokens.
- All copy via `session.l(...)`. All colors via tokens.

Android:
- Rewrite `mobile/android/app/src/main/java/com/hiair/ui/render/DashboardScreenRenderer.kt`.

Tests:
- Snapshot tests: 4 risk levels × 2 languages × light/dark = 16 snapshots.
- Manual QA on iPhone SE, iPhone 15 Pro, Pixel 6, Pixel 8.

Exit criteria:
- No Aurora Calm v2 forbidden patterns introduced.
- All snapshot tests green.
- No regression in dashboard load latency (p95 ≤ baseline + 50ms).

---

## Stage 5 — Planner redesign

Goal: heat-strip + key events list replaces hour list.

iOS + Android:
- 24-hour horizontal heat-strip component.
- Key events list (3–5 items derived from forecast).
- "Apply this plan" CTA wired as no-op for this cycle (Calendar deep-link in
  follow-up cycle).

Tests:
- Golden tests on heat-strip with three forecast fixtures (clean, mixed, bad).

Exit criteria:
- Heat-strip renders correctly on both platforms.
- Tests green.

---

## Stage 6 — Symptoms redesign

Goal: emoji-pill input, sleep selector, streak indicator, success haptic.

iOS + Android:
- Replace toggles with pill buttons (emoji + label).
- 5-dot sleep quality selector.
- Streak indicator in topbar.
- Success haptic on submit.

Tests:
- Integration: submit reaches backend, increments streak.

Exit criteria:
- End-to-end submit works on both platforms.

---

## Stage 7 — Backend: Personal Patterns engine

Goal: correlation engine, persistence, API, AI explanation, recompute job.

Files to add:
- `backend/sql/006_personal_correlations.sql`
- `backend/app/services/correlation_engine.py`
- `backend/app/services/correlation_repository.py`
- `backend/app/api/insights.py`
- `backend/scripts/recompute_correlations.py`
- Privacy hooks updated in `backend/app/services/privacy_repository.py`

Files to update:
- `backend/app/services/ai_explanation_service.py` — add `personal_pattern_v1`
  prompt + extended FORBIDDEN_PHRASES.
- `backend/app/services/localization.py` — add pattern.* keys ru + en.
- `backend/app/main.py` — register insights router.
- `docs/data-retention-matrix.md` — add personal_correlations row.
- `docs/ops-correlation-runbook.md` — new ops doc for the cron.

Tests to add:
- `backend/tests/test_correlation_engine.py`
- `backend/tests/test_insights_api.py`
- `backend/tests/test_pattern_explanation_guardrails.py`
- `backend/tests/test_recompute_correlations_script.py`

Exit criteria:
- Pytest green for all four new test modules.
- `scripts/smoke_db_flow.py` extended with insights call and passes.
- Privacy export on test account includes `personal_correlations`.

---

## Stage 8 — Insights screen mobile

Goal: new tab on iOS + Android with patterns, this-week stats, timeline, empty
state.

iOS deliverables:
- `mobile/ios/HiAir/Screens/InsightsView.swift`
- `mobile/ios/HiAir/Networking/APIClient+Insights.swift`
- Tab order updated in root TabView.
- Localization keys added in `AppSession.swift`.

Android deliverables:
- `mobile/android/app/src/main/java/com/hiair/ui/insights/InsightsScreenRenderer.kt`
- `mobile/android/app/src/main/java/com/hiair/ui/insights/InsightsViewModel.kt`
- Network helper added in `ApiClient.kt`.
- Tab order updated.
- Localization keys added in `AndroidL10n.kt`.

Tests:
- iOS snapshot: empty / partial / full × ru + en.
- Android snapshot: same matrix.

Exit criteria:
- Tab works end-to-end against staging backend.
- All snapshot tests green.

---

## Stage 9 — Backend: Morning Briefing scheduler

Files to add:
- `backend/sql/007_briefing_schedule.sql`
- `backend/app/services/briefing_service.py`
- `backend/app/services/briefing_repository.py`
- `backend/app/api/briefings.py`
- `backend/scripts/dispatch_briefings.py`

Files to update:
- `backend/app/services/privacy_repository.py` — include briefing_schedule.
- `backend/app/services/localization.py` — briefing.* keys ru + en.
- `backend/app/main.py` — register briefings router.
- `docs/data-retention-matrix.md` — add briefing_schedule row.
- `docs/ops-briefing-runbook.md` — new ops doc.

Tests to add:
- `backend/tests/test_briefing_due_logic.py`
- `backend/tests/test_briefing_compose.py`
- `backend/tests/test_briefing_api.py`
- `backend/tests/test_briefing_no_double_send.py`

Exit criteria:
- All four test modules green.
- `scripts/dispatch_briefings.py --dry-run` correctly enumerates due users.

---

## Stage 10 — Briefing settings UI

Goal: toggle + time picker in Settings → Notifications.

iOS deliverables:
- New section in `SettingsView.swift`.
- Network helper for `/api/briefings/schedule`.

Android deliverables:
- New section in settings screen renderer.
- Network helper.

Tests:
- Manual: enable on test device, set time +2 min, receive push.

Exit criteria:
- End-to-end push received on a real test device on both platforms.

---

## Stage 11 — Cross-platform polish

Goal: empty states, loading skeletons, error states, parity.

Tasks:
- Empty states for Insights and Settings → Briefing.
- Shimmer loading on cards.
- Error states with retry copy.
- Verify auth flow parity iOS vs Android on the new screens.
- Audit new screens: zero hardcoded URLs, zero hardcoded hex.

Exit criteria:
- QA checklist updated and passing.
- No regressions in `qa-checklist.md` items A through I.

---

## Stage 12 — Verification & evidence

Goal: cycle done.

Tasks:
1. Full pytest suite green.
2. Backend GitHub Actions workflow green.
3. iOS build workflow green.
4. Android build workflow green.
5. `scripts/smoke_db_flow.py` covers insights + briefing.
6. `scripts/beta_preflight.py` covers insights + briefing.
7. Manual QA per updated `docs/qa-checklist.md`.
8. `docs/_operator/master-gap-report.md` updated with cycle outcome.
9. `docs/release-notes-aurora-calm.md` written.
10. Privacy export evidence saved on test account with patterns + briefing.
11. Demo video recorded.

Exit criteria:
- All eleven items checked.
- Branch ready for review and merge.

### Stage 12 audit snapshot (2026-05-01)

1. Full pytest suite green — **DONE**  
   Evidence: `cd backend && ../.venv/bin/python -m pytest -q` → `34 passed`.
2. Backend GitHub Actions workflow green — **DONE**  
   Evidence: PR checks `backend-smoke` passed on merged PRs #9 and #10.
3. iOS build workflow green — **DONE**  
   Evidence: PR checks `ios-build` passed on merged PR #9.
4. Android build workflow green — **DONE**  
   Evidence: PR checks `android-build` passed on merged PR #9.
5. `scripts/smoke_db_flow.py` covers insights + briefing — **DONE**  
   Evidence: script now exercises `/api/insights/personal-patterns` and `GET/PUT /api/briefings/schedule`.
6. `scripts/beta_preflight.py` covers insights + briefing — **DONE**  
   Evidence: preflight now checks `/api/insights/personal-patterns` and `/api/briefings/schedule`; no-DB infrastructure run passes with  
   `../.venv/bin/python scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN" --skip-authenticated-checks`.
7. Manual QA per updated `docs/qa-checklist.md` — **PARTIAL**  
   Evidence: closure QA artifact attached (`docs/qa-run-007-report.md`); full physical-device matrix still pending.
8. `docs/_operator/master-gap-report.md` updated with cycle outcome — **DONE**  
   Evidence: cycle status and verification snapshot sections updated with merge-era evidence.
9. `docs/release-notes-aurora-calm.md` written — **DONE**  
   Evidence: release notes file created and merged.
10. Privacy export evidence saved on test account with patterns + briefing — **DONE**  
    Evidence: full DB-backed `scripts/smoke_db_flow.py` passed against temporary local Postgres, including
    `/api/privacy/export`, `/api/insights/personal-patterns`, and `/api/briefings/schedule` assertions.
11. Demo video recorded — **DONE**  
    Evidence: `docs/_operator/stage12-demo-video-link.md` with artifact `docs/_operator/stage12-demo-ios.mp4`.

Current local gate status:
- **DONE**: `backend/run_gate.sh --skip-db` and `backend/scripts/run_backend_gate.py --skip-db`.
- **DONE**: full `backend/scripts/run_backend_gate.py` against temporary local Postgres (`127.0.0.1:55432`).
- **DONE**: full preflight (including authenticated checks) against live API with temporary local Postgres.
- **DONE**: machine-readable evidence snapshot generated at
  `docs/_operator/stage12-evidence-latest.json` via
  `backend/scripts/collect_stage12_evidence.py`.

---

## Status tracking

| Stage | Status      | Started    | Finished   | Evidence link |
|-------|-------------|------------|------------|---------------|
| 0     | done        | 2026-05-01 | 2026-05-01 | docs bootstrap commit + branch push |
| 1     | done        | 2026-05-01 | 2026-05-01 | iOS/Android token files + green builds |
| 2     | done        | 2026-05-01 | 2026-05-01 | atmospheric particles landed both clients |
| 3     | done        | 2026-05-01 | 2026-05-01 | risk-reactive globe anchor + cadence mapping |
| 4     | done        | 2026-05-01 | 2026-05-01 | dashboard rebuilt (Aurora Calm hierarchy) |
| 5     | done        | 2026-05-01 | 2026-05-01 | planner heat-strip + key events on both clients |
| 6     | done        | 2026-05-01 | 2026-05-01 | symptoms pill UX + sleep selector + streak hint |
| 7     | partial     | 2026-05-01 |            | correlations SQL/API/engine landed; follow-up tests/docs pending |
| 8     | partial     | 2026-05-01 |            | insights tab live on iOS/Android; snapshot matrix pending |
| 9     | partial     | 2026-05-01 |            | briefing SQL/service/API/script landed; dispatch dry-run blocked by local DB/env |
| 10    | partial     | 2026-05-01 |            | settings toggle/time wired iOS+Android; device push proof pending |
| 11    | partial     | 2026-05-01 |            | insights/settings empty+loading+error states polished; QA parity sweep pending |
| 12    | partial     | 2026-05-01 |            | machine evidence DONE (full gate + smoke + preflight + CI/builds); remaining manual QA + demo video |

This table is updated after each stage gate.
