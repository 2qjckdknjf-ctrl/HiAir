# HiAir — дополнение к roadmap, 2026-09-23

> Последняя консолидация: 2026-10-23. Текущая очередь, доказательства, владельцы и gates — в разделе «Единая очередь 2026-10-23». Датированные разделы ниже сохраняются как история; одинаковые рекомендации не создают новые задачи.

Текущий продуктовый план: [Master Product & Engineering Spec](HIAIR_MASTER_SPEC_2026_2027.md). Этот amendment сохраняет security/release/research constraints; прежний [upgrade plan](HIAIR_MASTER_UPGRADE_PLAN_2026.md) — историческая база, интегрированная через PR83. Актуальные реализации и оставшиеся acceptance — в `docs/_operator/DELIVERY_REGISTRY.json`.
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

## Приоритеты подтверждены — 2026-09-26
Новой продуктовой фичи не добавлено. Сначала текущие security/release/data-integrity gates; затем AFTER RELEASE dataset → provider benchmark → ensemble baseline → local bias correction → shadow evaluation.
Shared agent identity/package/runtime/budget contracts применяются только при будущей интеграции HIAIR-ASSURE-003 и после готовности общего framework. Не переносить health memory/raw streams в agent packages или cloud checkpoints. Новые paid jobs/providers требуют approved scope/budget/data policy.
Сведения о runtime/model релизах из дайджеста не меняют deterministic risk engine, clinical/wellness framing или current release gates.

## Future UX/analytics — корректировка 2026-10-02
**HIAIR-FUTURE-UX-007:** proactive recommendation на существующих deterministic risk/action/alerts, FUTURE после текущего release. Отдельный health agent в текущем sprint не создавать.
Позднее сохранять consented feedback (accepted/ignored/explicit correction), reason/version, actual environmental conditions и source availability. Игнорирование не доказывает плохое качество; acceptance не доказывает health benefit/выполнение действия; outcome не диагноз и не причинность.
AC future analytics: opt-out, account-bound access, minimized/aggregate data, delete/revoke, timestamps и unknown outcomes. Никакой автоматической смены risk rules или отправки health data в общий corpus.
Shared Observer/Failure/Corpus contracts приходят через HIAIR-ASSURE-003 после готовности adapter. Product release/data truth/forecast roadmap сохраняет приоритет. Provider Benchmark/Ensemble/Bias Correction остаются AFTER RELEASE research; нового core-feature по этим сигналам нет.

## Roadmap clarification — 2026-10-03
Core roadmap без новых фич: release/data truth → provider benchmark → ensemble → bias correction по текущим gates.
Streaming voice остаётся HIAIR-VOICE-004 / FUTURE UX, только после foundations и отдельного product decision. SpeechProvider reuse возможен после готовности shared contract; deny mic/fallback/consent, data minimization и deterministic facts обязательны. Новые MAI/Gemini/Tavus dependencies не утверждены.
Общие host/secret/drift/routing contracts относятся к будущей HIAIR-ASSURE-003 интеграции, не к расширению health data доступа. Реализация forecast и publication остаётся приоритетом.

## Forecast uncertainty / scope clarification — 2026-10-07

PLANNED; уточнение HIAIR-RESEARCH-BIAS-005 / RESEARCH-PROVIDERS-006, AFTER RELEASE, без нового sprint/core agent. SEC-000 → REL-001 → PRED-002 и текущий deterministic personal-risk contract сохраняют приоритет.
Ensemble output: value/units/horizon/location, interval/type/coverage level, calibrated confidence/method/version, source_disagreement/method, freshness и source/model/provenance. Missing/unavailable поля null с reason; provider spread без calibration не объявлять confidence interval. Uncertainty валидируется held-out по городам/времени/regimes, extreme pollution/weather, drift и calibration, не только R².
AC: missing/stale/conflicting providers, uncalibrated model, out-of-domain и interval near risk threshold; заранее reviewed deterministic conservative handling, честное сообщение uncertainty, без false precision и автоматического изменения health rules. LLM только объясняет факты/ограничения. Benchmark candidate требует availability/license/source verification и доказанного улучшения existing baseline.
Исследование AQI одной станции/города из дайджеста — непроверенный research reference; не основание заменить ensemble. Общие DataScope/Flow/holdout/kill contracts — будущая HIAIR-ASSURE-003 integration; consented health data не попадает в общий corpus автоматически. Новых voice/providers/model dependencies и publication действий этим обновлением нет.

## Knowledge Layer — сигнал 7 октября, дополнение 2026-10-07 (вечер)

HIAIR-KNOWLEDGE-008: WATCH / FUTURE explanatory research, после release и текущего forecast truth/benchmark/ensemble/bias/uncertainty. Core risk/forecast architecture не менять.
Optional retrieval of licensed provider docs/environmental bulletins/event reports and permitted imagery через shared MultimodalRetrievalProvider; explanation сохраняет sources/time/location/freshness/uncertainty. AQI spike + wildfire bulletin association не established causality; unavailable source → insufficient explanation. Deterministic verified risk values отдельны от retrieved hypotheses.
AC future: scientific/source review, geographic/time relevance, contradictory/stale bulletins, prompt injection и citation faithfulness; tenant-safe consent/minimization/delete и pre-egress policy. Health data не generic corpus, local embeddings не automatic privacy. EmbeddingGemma candidate requires official availability/license and benchmark, no activation/dependency now.

## Сверка всех доступных AI разборов 2026-10-13

[Актуальная матрица функций и AC](AI_DIGEST_RECONCILIATION_2026-10-13.md) уточняет existing HIAIR-PRED/KNOWLEDGE/ASSURE и H-01/H-05 eval: immediate vs forecast exposure, source-backed explanations, recommendation vs forecast confidence, reproducible candidate benchmark. Существующие forecast/ACTION/health/release реализации не создавать повторно. Shared MCP/local-model/voice integration остаётся после current release/quality и отдельно доказанной необходимости. Source/data/uncertainty tests развивать в существующих suites; core forecasting/risk и flags не менять.


## Единая очередь 2026-10-23

Проверен `origin/main` **68a384061f46389f15fb161b9646904838aa65e1** и открытые PR на 23 октября 2026 (Europe/Madrid). Это обновление плана: ни merge, ни deploy, ни store submission не выполняются. Порядок требований: [Master Spec](HIAIR_MASTER_SPEC_2026_2027.md) → этот актуальный раздел → [delivery registry](../_operator/DELIVERY_REGISTRY.json) и отдельные release/device receipts. Исторические документы остаются доказательствами на свою дату, а не дополнительной очередью.

### Реализовано, предложено и ещё не подтверждено

| Состояние | Проверенное основание | Что остаётся открытым |
|---|---|---|
| MERGED / CODE_PRESENT: deterministic risk, forecast truth, ACTION bounds/ranking, timezone/DST, hazards, local calendar confirmation, free core | [PR83](https://github.com/2qjckdknjf-ctrl/HiAir/pull/83), [PR86](https://github.com/2qjckdknjf-ctrl/HiAir/pull/86); `backend/app/services/activity_plan_engine.py`, forecast services; existing risk/forecast/alert/activity test suites | Качество на независимом наборе, полная physical-device матрица и актуальная live-доставка не следуют из наличия кода |
| MERGED / CODE_PRESENT: pool, concurrent Insights, health batching, Apple renewal ordering/restore | [PR88](https://github.com/2qjckdknjf-ctrl/HiAir/pull/88), [PR89](https://github.com/2qjckdknjf-ctrl/HiAir/pull/89) | Registry ещё ссылается на #88/build302; #89 уже merged, но доставка 303 и успешный физический restore этим проходом не подтверждены. Не реализовывать batching/restore повторно |
| HISTORICAL_RUNTIME_EVIDENCE: build302/API и один iPhone Insights сценарий | [Current delivery status](../_operator/CURRENT_DELIVERY_STATUS.md), [manifest302](../release/RELEASE_MANIFEST_302_2026-10-11.json) | Доказательства от 11 октября; один тест 5.44s не p95 и не полная сертификация. Свежий production SHA не проверялся |
| PR_ONLY: manual production approval и Play public link | [PR90](https://github.com/2qjckdknjf-ctrl/HiAir/pull/90) OPEN DRAFT, [PR80](https://github.com/2qjckdknjf-ctrl/HiAir/pull/80) OPEN DRAFT | #90 зависит от protected environment reviewers/main-only и последующего staging same-SHA gate; #80 зависит от реально доступной Play-страницы. Их наличие не закрывает gate |
| PLANNED: full independent benchmark, scoped ROMA adapter, provider comparison/bias/knowledge/voice | Existing HIAIR IDs ниже; [13 October inventory](AI_DIGEST_RECONCILIATION_2026-10-13.md) | Требуются выделенный срез, воспроизводимое доказательство и отдельное решение о выпуске |

### Дедупликация AI Scout и разборов

Проверены файлы и состояние всех трёх draft PR: [#92 / 15 октября](https://github.com/2qjckdknjf-ctrl/HiAir/pull/92), [#93 / 18 октября](https://github.com/2qjckdknjf-ctrl/HiAir/pull/93), [#94 / 20 октября](https://github.com/2qjckdknjf-ctrl/HiAir/pull/94). Все OPEN DRAFT; ни один не считается внедрением. После одобрения этой консолидации их содержание представлено следующими existing IDs; не переносить dated addendum как отдельные очереди. Исходные ветки/PR сохраняются до review, их закрытие не выполнялось.

| Источник | Единственное место в очереди |
|---|---|
| #92: deterministic engine/provenance, PM2.5/stale/notifications | HIAIR-SEC-000/PRED-002: data integrity и независимый regression corpus |
| #92: explanation factuality/latency/cost, candidate LLM | HIAIR-KNOWLEDGE-008: offline explanation evaluation; смена модели P2 |
| #93: Search & Fetch, source trust/freshness; no web-derived measurements | HIAIR-KNOWLEDGE-008 и PRED-002; внешние тексты только explanatory references |
| #94: Risk Engine coding benchmark | PRED-002, тот же корпус; не второй Risk Engine |
| #94: alternative compute | RESEARCH-PROVIDERS-006: P2 watch при доказанной потребности |
| Разборы 21–23 октября: independent monitoring, agent authority, credential brokering, быстрый routing/Decisions API, skill metrics | ASSURE-003 использует общие ROMA/Grow contracts. Decisions API — кандидат в отдельный benchmark explanation/routing; вычисление риска остаётся deterministic. Новые vendor SDK и права не разрешены этой записью |

[Разборы](https://chatgpt.com/c/6ac9d8f6-bca8-83ed-a870-d505bf1c9c69) — входные рекомендации, не доказательства API availability, clinical efficacy или реализации. Последние доступные тексты 21–23 октября были ограничены выгрузкой; непроверенные названия/метрики остаются кандидатами. [Decisions API, 22 октября](https://openai.com/index/decisions-api/) подтверждает bounded classification/choice/score, но не скорость/качество на HiAir; [METR monitoring exercise, 22 октября](https://metr.org/blog/2026-10-22-red-teaming-openai-agent-monitoring/) мотивирует независимую проверку полноты событий и относится к системе на дату упражнения, не доказывает текущее состояние после исправлений. [1Password for AI agents](https://1password.com/blog/1password-for-ai-agents) — возможный Credential Broker adapter; account support и containment сессии ещё не подтверждены. Перед experiment проверить доступность для аккаунта, endpoint/version, data policy, цену/лимиты и воспроизводимость; отсутствие подтверждения блокирует vendor-specific spike, но не общие тесты данных.

### Приоритеты, владельцы, зависимости и приемка

Владельцы ниже — ответственные **роли**, персональное назначение не подтверждено (TBD). P0 — gate до затрагиваемого выпуска; P1 — следующий ограниченный срез; P2 — отложенный experiment. Вехи зависят от доказательств, календарные сроки не обещаются.

| Existing ID / приоритет / состояние | Ответственный / зависимость / веха | Измеримые критерии приемки |
|---|---|---|
| HIAIR-SEC-000 + REL-001 / **P0**, hardening delivered, release gaps OPEN | Release/Security lead (TBD); текущие protected checks; **H0** | Сверить #89 main SHA, фактический deployed fingerprint, signed artifact hash, installed version и device run отдельно. До promotion ноль failing обязательных consent/revoke/account-switch/stale/null/store-verifier cases. #90 нельзя считать закрытым без доказанных reviewer/main-only настроек; каждый merge/deploy требует отдельного подтверждения пользователя |
| HIAIR-PRED-002 / **P0 инварианты, P1 расширение tests**, PARTIAL | Backend/data QA (TBD); H0 для выпуска, offline tests могут готовиться параллельно; **H1** | Один frozen versioned corpus в существующих `test_air_risk_engine`, forecast, alert и activity suites: PM2.5 spikes, missing/stale/future timestamps, units, current-vs-forecast, DST, gaps в hourly intervals, risk-threshold edges, null→not-zero, notification cooldown/quiet hours. Expected outputs задаёт reviewer независимо от изменяющего код агента. 100% critical cases PASS, ноль fabricated measurements; exact SHA/provider/config/dataset hash и raw run evidence |
| HIAIR-REL-001 / **P0**, DEVICE_ACCEPTANCE_PARTIAL | Mobile QA/Release (TBD); H0/H1; **H2** | iPhone restore и ACTION/calendar/consent/offline/account-switch на установленной candidate version; physical Android ACTION/Health Connect/Play Billing. По каждому тесту executed/pass/fail/skip и устройство. Отсутствующее устройство = BLOCKED, не PASS. Последний historical успешный тест сохраняется |
| HIAIR-KNOWLEDGE-008 / **P1 offline**, model change **P2** | AI eval + domain reviewer (TBD); H1 facts и approved data policy; **H3** | Baseline template/current model vs candidate на одинаковом замороженном наборе во всех поддерживаемых локалях; не менее 3 повторов. Ноль critical false numerical/risk claims и unauthorized health-data egress; source/time/location/citation, contradiction/no-source/abstention cases. Отчёт factuality, fallback, p50/p95 latency и total cost per independently verified explanation; threshold/budget задать до run. Победитель не назначается по одной vendor-метрике |
| HIAIR-ASSURE-003 / **P1 контракт, P2 включение**, PLANNED | ROMA adapter + Privacy lead (TBD); H1–H2, readiness ROMA independent verifier / Dynamic Agent Authority / Credential Broker и Grow approval queue; **H4** | Advisory read/propose adapter: task/repo SHA/config/input hash → deterministic expected result → independent verdict. Deny expired/revoked/cross-account scope, logs cover allowed/denied/failed tool actions without raw health/precise location/secrets. У evidence есть retention/source access; no agent self-approval. Включение только после privacy review и готового disable path |
| HIAIR-RESEARCH-PROVIDERS-006 + BIAS-005 / **P2**, AFTER RELEASE | Data science (TBD); H2 + licensed aligned forecast/observation pairs; **H5** | Pre-registered sample minimum/coverage; issue-before-observation and temporal/geographic holdouts. Raw provider → simple ensemble → correction; MAE/RMSE/bias, extreme slices, missingness, uncertainty calibration и drift отдельно. Никакой production смены без положительного shadow report и отдельного release review |
| HIAIR-FUTURE-UX-007 / VOICE-004; AMBIENT → ROUTES → TWIN → HOME+CARE / **P2**, DEFERRED | Product owner (TBD); H2, existing master-spec phase gates; later milestone | Для каждого этапа отдельный approved scope и existing-spec AC; consent/minimization/revoke обязательны. Принятие рекомендации не доказывает медицинский эффект. Voice/новый provider/compute лишь после конкретной подтверждённой потребности |

Безопасная последовательность: H0 evidence/release gate → H1 deterministic data regression → H2 real device acceptance → H3 offline explanation comparison → H4 advisory integration → H5 data research и дальнейшие product phases. Tests и проверка публичных provider contracts допускаются параллельно; production действия, реальные health data egress и полномочия не расширяются. Изменения provider/model/config invalidates соответствующий benchmark и требуют повторной независимой проверки.

### Нерешённые блокировки на дату сверки

1. Физический Android и полная device/privacy/store матрица не подтверждены; iPhone restore completion остаётся открытым.
2. Delivery registry/main расходятся по #89: нужен свежий immutable deployment/artifact/device readback, а не повторная реализация.
3. #90 OPEN: protected production reviewers/main-only и staging isolation/same-SHA evidence не подтверждены; #80 public Play URL требует живой проверки до изменения CTA.
4. Независимый corpus/owners и заранее согласованные cost/latency budgets ещё должны быть зафиксированы; новостные API и shared ROMA/Grow adapter readiness не доказаны этой документацией.
