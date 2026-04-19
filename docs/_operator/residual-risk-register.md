# HiAir Residual Risk Register

Last updated: 2026-04-19

Residual risks after current engineering closure and merged CI updates.

| ID | Risk | Impact | Likelihood | Mitigation | Trigger to escalate |
|---|---|---|---|---|---|
| R-001 | Store upload blocked by missing platform account access | high | medium | external owner assignment and deadline tracking in blocker ledger | missed upload rehearsal date |
| R-002 | Legal text drift between drafts and final policy pages | high | medium | legal signoff workflow with final URL lock before beta expansion | unresolved legal comments near release date |
| R-003 | Contract alias removal could break older clients if done too early | medium | medium | keep alias telemetry and versioned deprecation rollout | non-zero alias usage near removal window |
| R-004 | Ops incident handling maturity still limited for sustained public scale | medium | medium | run beta incidents using incident runbook; refine response playbook | repeated P1 incidents with slow recovery |
| R-005 | Device QA matrix may miss edge-case regressions on untested OS/device combinations | medium | medium | expand matrix and mandatory run reports before public launch | critical issue found post-release on untested class |

## Current posture

- Engineering CI and core backend/mobile checks are now in controlled state.
- Residual risk profile is dominated by non-code operational and external dependencies.
