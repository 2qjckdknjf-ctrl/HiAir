# ACTION analytics and quality contract

Preserve existing event names; do not double-count aliases as independent events. The current iOS unified log / Android OS log is diagnostic instrumentation, not a server analytics database. No raw health, symptoms, exact coordinates, account IDs, tokens or calendar contents belong in these events.

| Existing event | Canonical meaning | KPI |
|---|---|---|
| planner_opened / dashboard planner navigation | action_planner_opened | entry count |
| activity_type_selected | action_type_selected | activity choice |
| activity_plan_loaded / activity_plan_created | action_plan_generated | generation success |
| activity_plan_fetch_failed | action_plan_generation_failed | failure rate |
| activity_plan_marked_planned | action_plan_accepted | explicit acceptance |
| activity_plan_followed | action_plan_completed | explicit user report, not verified health outcome |
| action_time_preference_selected | time preference | constraint use |
| action_calendar_editor_opened | calendar editor opened | export intent |
| action_plan_calendar_added (iOS) | native editor confirmed save | calendar saves |

Android calendar ACTION_INSERT does not reliably report a saved event, so it records only editor opening. Do not fabricate a saved/completed event. A rendered window is not a selected/accepted action. Dismiss/completion events require a real user action; the current UI must not invent them.

Free acceptance is local per loaded plan; premium acceptance reuses Protected Day recording. Neither promises durable ActionPlan persistence. The local calendar export needs no new lifecycle table, RLS, or collection of unrelated calendar data.

Hypothesis: explicit duration/intensity/place/time controls and a usable free recommendation improve planner acceptance/reuse. Measure acceptance per successful generation and repeat planner use during beta; target >=10% relative improvement without higher auth/data/privacy failures. This is a target, not an achieved result. A beta sample and independent observation period are required before declaring product-quality improvement.

`scripts/release/evaluate_action_ranking.py` captures/replays reference-city live forecasts and compares deterministic ranking against historical first-valid selection. It checks ranking/non-regression, not provider accuracy, clinical benefit or user adherence. October 11 capture: 9 contexts, 6 comparable, 0 score regressions, 0 score improvements (remaining contexts had no valid action). The result does not close the real-world quality criterion. Regression fixtures separately prove later stronger candidates win and forecast gaps cannot become continuous windows.
