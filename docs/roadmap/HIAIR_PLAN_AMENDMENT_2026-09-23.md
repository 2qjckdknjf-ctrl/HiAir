# HiAir — дополнение к roadmap, 2026-09-23

Статус: PLANNED, интеграционный backlog. [Master plan](HIAIR_MASTER_UPGRADE_PLAN_2026.md) остаётся каноническим.
Baseline main: ea8bd8d5df55c49b9b33d5953b3eb9979f07ea31. Исторические DEPLOYED записи master plan не перепроверены этим docs update.

| ID / порядок | План и acceptance criteria |
|---|---|
| HIAIR-SEC-000 / P0 | Сверить существующие integrity/privacy/auth release gates и открытые работы. Cross-account доступ, revoke/delete после logout, denied health consent, stale/null forecast остаются отрицательными AC. Не создавать новый security framework внутри продукта. |
| HIAIR-REL-001 / P0 | Закрыть текущие реальные release/device gaps по master plan и AGENTS; production SHA, API smoke, physical-device evidence и store readiness фиксируются раздельно. Существующие реализованные 1.1–2.0 функции не переписывать как новые. |
| HIAIR-PRED-002 / после release gates | Продолжить Forecast Truth → Best Time → hazards/alerts в текущем roadmap. Forecast provenance/freshness/DST, unavailable values и deterministic risk/action engine обязательны; AI только объясняет результат. Связать AC с requirement/evidence, проверять stale evidence после изменения risk/provider config. |
| HIAIR-ASSURE-003 / P1 интеграция | Подключить общие ROMA contracts после готовности adapter: requirement coverage и independent verdict сначала advisory. Environment verifier подтверждает account/project/API environment; egress разрешает только согласованные минимальные данные. Никаких raw health streams или точной location в общих traces; revoke блокирует новые uploads. |
| HIAIR-VOICE-004 / DEFERRED | Voice runtime лишь кандидат после стабильных data/release/prediction gates и отдельного product decision. Нового чата, voice UI и provider SDK сейчас не добавлять. |

Shared assurance contract: Aistroyka-web/docs/roma/ROMA_EXECUTION_ASSURANCE_PLAN_2026-09-23.md (план, не внедрённая зависимость).
Маркетинговый growth-os получает только разрешённую агрегированную продуктовую телеметрию; credentials и health DB не передаются.
Версии моделей и benchmarks из внешних AI-дайджестов не проверены; перед будущим spike нужны официальные API/data-policy/eval evidence.

Cursor: прочитай AGENTS и master plan; сначала составь gap list текущего release на актуальной ветке. Этот amendment не разрешает merge active stack в main, deploy, store uploads или новые медицинские claims. Обновления мобильного UI остаются additive на существующих tabs.
