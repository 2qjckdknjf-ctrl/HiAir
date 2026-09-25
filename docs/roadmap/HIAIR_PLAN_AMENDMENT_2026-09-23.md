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

## Research amendment — 2026-09-24
**HIAIR-RESEARCH-BIAS-005 — Local forecast bias correction. Статус RESEARCH / AFTER RELEASE.**
Детализация HIAIR-PRED-002, не новый AI-agent и не изменение текущего risk engine.
После текущих release/data-integrity gates собрать provider forecast ↔ independently observed pollutant pairs: provider/model revision, issued_at, valid_at, forecast horizon, station/location, units, quality, time zone и ingestion timestamp. Forecast должен быть выпущен ДО соответствующего observation; retrospective revised forecast не допускается как честный прогноз.

Offline baseline по pollutant/location/season/hour/weather regime; сравнить raw provider, простой calibration baseline и кандидат correction model. Выбор алгоритма (включая LightGBM) не утверждён.
AC: temporal walk-forward и geographic holdout без leakage; минимум объёма/полноты данных фиксируется до эксперимента; MAE/RMSE/bias и ошибки при высоких концентрациях отчётны отдельно по регионам/горизонтам. Проверять drift и худшие slices, а не только среднее улучшение.
Raw forecast сохраняется; corrected output имеет provenance/version/uncertainty и label calibrated. Не заменять unavailable measurement прогнозом и не превращать correction в observed data. При недостаточных данных или деградации — исходный разрешённый forecast либо unavailable по действующим правилам.
Promotion: воспроизводимый offline report → shadow evaluation → отдельный review и release gates. До этого никаких correction в production recommendations.
Климатические ozone projections и краткосрочный operational forecast — разные задачи; проценты улучшения из дайджеста не переносятся на HiAir. Research не требует raw health/precise user-location data.

## Forecast evaluation research — 2026-09-25
**HIAIR-RESEARCH-PROVIDERS-006 — Provider Benchmark / Ensemble. RESEARCH, AFTER RELEASE.**
Продолжение HIAIR-RESEARCH-BIAS-005. Research sequence: aligned forecast/observation dataset → raw provider benchmark → simple ensemble baseline → local bias correction comparison → shadow evaluation. Ensemble не обязательная production зависимость и не основание менять текущего provider.

Сравнивать providers и correction candidates с independent observations по location/station, pollutant/variable, forecast horizon, local hour, season, weather regime. Provider Score обязан показывать метрику, sample count, coverage/missingness, freshness, interval uncertainty и dataset version; не сводить разные pollutants/horizons в непрозрачный общий рейтинг.
AC: одинаковые issued-before-observation cutoffs и горизонты; никакого leakage через revised forecasts, station overlap в holdout или обучение на evaluation period. Наряду с matched samples показывать availability каждого provider: нельзя улучшить score, удаляя трудные/пропущенные случаи. Проверить licensing/provenance данных, geographic/time holdouts и drift.
Ensemble weights обучаются только на training window, versioned и сравниваются с raw/simple baseline; correlated sources не считаются независимыми доказательствами. При недостатке observations — insufficient evidence, не автоматический winner.
Shadow promotion требует улучшения заранее выбранных метрик без ухудшения critical slices и проверки current risk/release gates. Raw/corrected/ensemble provenance различается, unavailable остаётся честным. Никакой production смены маршрутизации прогнозов этим планом.
ECMWF/WMO и sub-seasonal материалы из дайджеста — непроверенные research references; перенос результатов на почасовой personal forecast не предполагается. Новую AI-agent/voice функцию не добавлять.
