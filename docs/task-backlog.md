# Task Backlog (перезапуск с нуля)

## Stage 0 - Foundation (выполнено)

- [x] Сформировать базовую документацию из PDF.
- [x] Зафиксировать MVP scope, архитектуру и backlog.

## Stage 1 - Research and planning (из Phase 1)

- [x] Провести сравнительный анализ API: OpenWeatherMap, WAQI, AirNow.
- [x] Зафиксировать формулу risk score и пороги по WHO/CDC.
- [x] Проверить требования по GDPR/CCPA и wellness positioning.
- [x] Утвердить стек:
  - [x] Mobile: native
  - [x] Backend: FastAPI
  - [x] Database: PostgreSQL
  - [x] Environmental API providers: OpenWeatherMap + WAQI

## Stage 2 - MVP development (из Phase 2)

### Backend
- [x] Data ingestion service skeleton (weather + AQI, mock/live modes).
- [x] Risk engine v1 (rule-based).
- [x] User management API (auth + profile CRUD, PostgreSQL-backed).
- [x] Notification integration point:
  - device token registration
  - dispatch stub fan-out
  - provider adapter layer (FCM/APNs dry-run hooks)
- [x] User settings persistence API (`GET/PUT /settings`).

### Mobile
- [x] Onboarding/profile setup (skeleton state/screens).
- [x] Home dashboard (overview-based skeleton).
- [x] Daily planner (skeleton + API integration).
- [x] Symptom log (skeleton + API integration).
- [x] Settings (skeleton state/screens).
- [x] Root navigation shell (tabs/screens composition skeleton).
- [x] Runnable project scaffolds:
  - Android Gradle skeleton
  - iOS XcodeGen spec

### Validation and infra
- [x] Валидация алгоритма на исторических событиях (baseline cases + API/script).
- [x] Настройка CI/CD (backend compile + smoke workflow).
- [x] Базовые логи и мониторинг (structured logs + `/observability/metrics`).

### Progress notes
- [x] Добавлен SQL init schema: `backend/sql/001_init.sql`.
- [x] Добавлен notification preview skeleton endpoint.
- [x] Auth/profile переведены на PostgreSQL repository.
- [x] Добавлены symptom log API и risk history API.
- [x] Добавлен DB bootstrap script: `backend/scripts/init_db.py`.
- [x] Добавлен native mobile API skeleton (iOS/Android).
- [x] Добавлен DB smoke flow script: `backend/scripts/smoke_db_flow.py`.
- [x] Добавлены onboarding/dashboard skeleton файлы для iOS и Android.
- [x] Добавлено сохранение notification preview events в БД.
- [x] Android dashboard wired на `/environment/snapshot` + `/risk/estimate`.
- [x] Добавлен endpoint `recommendations/daily` на основе history + symptoms.
- [x] Добавлен агрегированный endpoint `/dashboard/overview` для мобильного dashboard.
- [x] iOS/Android dashboard переведен на `/dashboard/overview`.
- [x] Dashboard state расширен daily actions + notification text (iOS/Android).
- [x] Добавлен planner endpoint и мобильные planner skeleton модели/VM.
- [x] Добавлен корневой navigation shell для iOS и Android.
- [x] Settings state связан с backend persistence (`GET/PUT /settings`).
- [x] Добавлена регистрация device token и dispatch stub endpoint.
- [x] Добавлен provider adapter слой для FCM/APNs (config-driven).
- [x] Добавлен retry policy skeleton и журнал delivery attempts.
- [x] Добавлен provider health endpoint и live auth skeleton (FCM v1/APNs JWT env-based).
- [x] Добавлен endpoint аудита delivery attempts для мониторинга отправки.
- [x] Добавлен credentials health + rotation audit API для push secrets.
- [x] Добавлен secret source abstraction (`env` / `file`) + runtime secrets refresh endpoint.
- [x] Добавлен HTTP secret backend для `secret_store` (Vault/Cloud-style).
- [x] Добавлен `secret-store-health` endpoint для диагностики внешнего secret source.
- [x] Добавлен Vault KV v2 backend для `secret_store`.
- [x] Добавлен GitHub Actions workflow для backend smoke tests.
- [x] Добавлен historical risk validation endpoint + script.
- [x] Добавлен observability endpoint и middleware структурированных логов.
- [x] Добавлены runnable mobile project scaffolds (Android/iOS).
- [x] Android `MainActivity` доведен до интерактивного screen shell.
- [x] iOS flow переведен на shared `AppSession` и связанный onboarding->tabs сценарий.
- [x] Добавлен публичный endpoint `GET /risk/thresholds` и документ `risk-thresholds-v1`.
- [x] Добавлены документы `beta-readiness-checklist` и `qa-checklist`.
- [x] Добавлен beta execution package: runbook + release notes + bug report template.
- [x] Добавлены legal drafts: Privacy Policy + Terms of Service.
- [x] Добавлен `backend/scripts/beta_preflight.py` для pre-release API checks.
- [x] Выполнен beta cycle 001 backend preflight, добавлен отчет.
- [x] Добавлен командный гайд `mobile-beta-build-commands.md` для TestFlight/Internal.
- [x] Добавлен Gradle Wrapper в Android-проект для воспроизводимой CLI-сборки.
- [x] Выполнен beta cycle 002: backend checks + iOS archive + Android APK/AAB.
- [x] Выполнен QA run 001 (automated pre-beta checks), добавлен отчет.
- [x] Выполнен QA run 002 (security/subscription hardening alignment), добавлен отчет.
- [x] Добавлен `store-upload-last-mile.md` для финального publish шага.
- [x] Выполнен full mobile audit и устранены ошибки открытия/сборки (`mobile-audit-2026-04-07`).
- [x] Добавлены privacy endpoints (`/api/privacy/export`, `/api/privacy/delete-account`) и обзор `gdpr-ccpa-wellness-review`.
- [x] Добавлен retention cleanup script для operational данных (`backend/scripts/retention_cleanup.py`).
- [x] Добавлен ops runbook планировщика retention cleanup (`docs/ops-retention-runbook.md`).
- [x] Усилен backend CI: strict env/security checks + retention dry-run + historical validation.
- [x] Выполнен QA run 003 (CI hardening), добавлен отчет.
- [x] Добавлен ops handover checklist для запуска scheduled maintenance (`docs/ops-handover-checklist.md`).
- [x] Добавлен единый backend gate orchestrator script (`backend/scripts/run_backend_gate.py`).
- [x] Выполнен QA run 004 (backend gate + свежие mobile build проверки), добавлен отчет.
- [x] Выполнен QA run 005 (artifact manifest automation), добавлен отчет.
- [x] Подготовлен release package документ для ручной store upload передачи (`docs/release-package-2026-04-07.md`).
- [x] Выполнен QA run 006 (mobile auth wiring fixes), добавлен отчет.

## Stage 3 - Beta and launch prep (из Phase 3)

- [x] Подготовлен beta readiness checklist.
- [x] Подготовлен QA checklist по сценариям.
- [ ] Закрытая бета (TestFlight + Google Play Internal Test).
- [ ] QA по устройствам/версиям ОС (по чеклисту).
- [ ] Privacy/ToS финализация (drafts готовы, требуется legal review).
- [ ] Прелендинг и ранние регистрации.

## Следующий исполняемый шаг

1. Загрузить готовые артефакты в TestFlight/Internal Test (нужны доступы Apple/Google).
2. Выполнить `docs/qa-checklist.md` на iOS/Android и зафиксировать баги по шаблону.


## Weekly AI reconciliation — 2026-11-10

**Period:** 2026-11-03 through 2026-11-10. **Status:** planning-only, not implementation or deployment. Existing canonical IDs, P0 gates and historical records take precedence. Reconcile with currently open PRs and exact HEAD before marking any item DONE. Evidence = reproducible tests + independent review + SHA + deployment/device receipt where applicable. Source ideas: OpenAI engineering/CAD and agent safety, GitHub Xcode and review telemetry, AI Engineer talks on durable SDLC, factual numeric provenance, adaptive worker economics, rollback, memory validity, and new Anthropic/Meta model announcements. Vendor benchmarks are not local acceptance evidence.

| Priority | Existing workstream / ID | Incremental action and acceptance |
|---|---|---|
| P0 | HIAIR-REL-001 / existing release gates | Complete physical-device QA, UX-05/12, data freshness and store receipts on exact build; preserve current deterministic Risk Engine. |
| P1 | Existing ingestion / provider-quality tests | Missing/stale provider readings must be unknown/blocked, not zero AQI; preserve timestamp, provider, units, source, fallback and alert evidence; test historical edge cases. |
| P1 | Existing product analytics | Measure real usage, retention and user decisions for Best Time, Morning Briefing and AI explanations before adding AI chat; A/B with privacy protections. |
| P2 | Local model / visualization research | Evaluate lightweight on-device explanations or maps only after release gates, benchmark latency, battery, accuracy and consent. |

**Implementation order:** close existing P0 first; P1 in bounded non-production pilots; P2 only after evidence-based decision. Owner: project engineering lead (assignment TBD); independent reviewer: ROMA/security or domain QA (assignment TBD). No auto-merge, production writes, payments or live trading from this roadmap update.

**Cross-project dependency:** Grow OS orchestrates; ROMA enforces independent policy/verification in Aistroyka-web; Sasha Memory OS stores permission-scoped evidence. Trading repository/runtime remains unverified; shared trading requirements are point-in-time market data, deterministic calculations, independent risk limits, exchange-state reconciliation, paper trading and kill switch, with no autonomous live orders.


### AI feature delta — 2026-11-11

These are **proposed additions to existing workstreams** from the November 11 intelligence review, not claims of shipped functionality or verified vendor capabilities. Validate official release/API/pricing availability before selecting any provider; independent exact-SHA acceptance and existing P0 gates remain mandatory.

- **P1 / existing explanation UI:** benchmark Gemini 4 Carbon or a cheaper model for grounded multilingual explanations of deterministic Risk Engine outputs, with citations, uncertainty, stale-data blocking and privacy checks; do not change Risk Engine thresholds.
- **P1 / voice accessibility research:** optional voice questions map to the same read-only recommendation and permission context; test interruptions, latency, battery and accessibility only after physical-device/release gates.
- **P1 / supply-chain:** verify Dependabot alert coverage on inactive supporting repos and dependency snapshots; do not assume alerts disabled.

**Acceptance rule:** record baseline, owner, independent reviewer, test corpus, security/privacy gates, cost per verified task and explicit decision (adopt / defer / reject). No autonomous production actions or merge authorized by this documentation.


## Gap-only AI roadmap reconciliation — 2026-11-20

**Review period:** 2026-11-12–2026-11-20. Compared this branch with `main` and the existing Nov 10/11 reconciliation. Only incremental acceptance conditions and candidate evaluations are recorded; pre-existing capabilities must not be rebuilt. **PLANNING ONLY / NOT IMPLEMENTED / NOT MERGED.** The owner and independent reviewer remain TBD until assigned. Recheck exact HEAD, CI and production receipts before any DONE status.

| Priority | Existing owner / workstream | Newly identified gap / acceptance evidence |
|---|---|---|
| P0 | Existing HIAIR-REL-001 / delivery gates | Physical device/UX/release receipts and exact-build data freshness first. No new AI feature is a prerequisite. |
| P1 | Existing provider reliability and monitoring | Performance Factory-inspired alert→investigate→independent validation→fix→post-release verification for stale AQI, missing API data, false zero readings and provider outages. Risk Engine remains deterministic. |
| P1 | Existing optional AI explanation / voice | Benchmark low-cost cloud/local models only on grounded deterministic AQI recommendations, Spanish/Russian accessibility, latency and privacy; no raw health profile to unapproved provider. |
| P2 | Existing marketing/analytics | Measure verified user action and retention before adding conversational interfaces; avoid claims of improved air-quality prediction without data. |

**Source references:** [OpenAI Performance Factory](https://openai.com/index/how-openai-performance-factory-keeps-chatgpt-fast/), [Google Mirror Dimension](https://blog.google/security/mirror-dimension-for-agents/), [OpenAI frontier risk controls](https://openai.com/index/managing-frontier-ai-risk/). Other recent model/vendor announcements are *candidates requiring independent availability and price validation*, not approved dependencies. No new runtime privileges, model installation, migrations, payments, deployment, PR merge, or trading orders are authorized by this document.


## Codex / Cursor execution delta — 2026-11-24

Planning reconciliation for 21–24 November; incorporates previously unrecorded 21–22 November recommendations. Existing workstreams and IDs own these acceptance extensions; do not duplicate implemented features. Vendor names/releases are research candidates from daily digests, not independently verified dependencies. Before execution, read current main, this planning branch and active implementation PRs; reconcile against code and evidence. Main blob at review: `e4f2339c0a71a684787a138677f8e318798bf48b`. P0 existing blockers first; P1 bounded sandbox pilots; P2 research. Owner/reviewer TBD. No production changes, automatic merge, purchases or live trading authorized.

- P0 existing release/privacy gates: verify API secrets absent from commits, prompts and logs; approved final inference providers, retention and user-data minimization; synthetic incident/revocation test.
- P2 existing provider reliability: evaluate Strands Decider for classifying source failures and support events, not AQI forecasts or risk thresholds; benchmark against rules and abstain on uncertainty. Preserve deterministic Risk Engine and device/release priority.

**Codex/Cursor execution contract:** produce gap matrix (implemented/partial/missing/blocked), map each item to existing task ID, implement only verified gaps on separate implementation branch, preserve existing tests and add negative/regression tests, report exact SHA, reproducible commands/results, independent reviewer verdict, cost and remaining blockers. Do not mark DONE on documentation or build alone. Validate candidate upstream documentation and licenses before installing or sending data. Stop on missing permissions or unsafe effects.


## Cursor execution specification — 2026-11-26

Planning-only delta for 25–26 November. Read current main and active implementation PRs first; map to existing IDs, implement only confirmed gaps. Vendor claims require primary-source verification. Existing P0 gates remain first. Proposed numerical thresholds are initial configurable test defaults, not measured results. No auto-merge, deployment, purchases, ad activation or live trading. Owner/reviewer TBD.

### P1 — existing analytics and provider reliability
Reconcile HiAir PR #105 and Growth PR #68 current HEAD/status before changes; existing disabled experiments remain disabled absent approval. Define privacy-minimized event contract for App Store click, first useful recommendation, repeat use and retention; dedupe, consent, schema compatibility, test synthetic events end-to-end. Evaluate Google Ads iOS measurement/target ROAS only after verifying availability and lawful data handling; never send precise location or health data to ad platforms. No activation or spend.
Prototype two-stage anomaly research: detect unusual AQI/source behavior, independently verify with timestamped observations and deterministic rules, distinguish missing/stale data from actual pollution. Holdout test false positives/negatives; do not modify Risk Engine thresholds or release gates.

### Cursor delivery contract
Work in a separate implementation branch; report gap matrix, changed files, reproducible commands, test receipts, exact commit SHA, independent verdict, rollback and remaining blockers. Never mark DONE from documentation/build alone. Stop on missing authorization, hardware access or provider compatibility; report NOT_RUN rather than fabricate evidence.


## Cursor / Codex execution delta — 2026-11-27

Planning-only extension to November 26 specification. Reconcile current main, active PRs and actual code before execution; map to existing IDs, implement only confirmed gaps. P0 blockers first. Vendor claims from daily digest require primary-source verification before adoption. Numerical corpus sizes are proposed test defaults, not measured results. Owner/reviewer TBD.

- P1 existing provider reliability/forecast validation: compare historical forecasts as issued at timestamp with subsequent observations, preserve provider/version/location granularity and availability timestamp; no future leakage, distinguish stale/missing data, evaluate MAE/bias and anomaly false positives on chronological holdout. Historical web providers optional for contextual research, not substitute for authoritative AQI observations. Keep deterministic Risk Engine and existing release gates unchanged.
- P1 existing analytics: prioritize consented user feedback and verified outcomes, no sensitive location/health data in external research tools.

Delivery: separate implementation branch, baseline and gap matrix, reproducible tests, exact SHA, independent verdict, rollback and blockers. No automatic merge, production deployment, purchases or live trading. Sources for verification: https://huggingface.co/nvidia/Nemotron-3.5-Parse ; https://onchainbench.ai/methodology ; https://www.perplexity.ai/en-GB/hub/blog/freeze-the-web-with-perplexity-time-machine ; https://openclaw.ai/blog/shellbench ; https://sakana.ai/marlin-update-2/ .

## Cursor / Codex execution delta — 2026-11-28

PLANNING ONLY. Owner requested incorporation of daily AI review. Reconcile current main, exact HEAD, active PRs and existing task IDs before execution; implement only verified gaps, existing P0 release blockers first. Numerical corpus sizes are proposed, not measured. Verify upstream release/license/runtime/privacy before adoption. Owner/reviewer TBD. No automatic merge, deployment, production mutation, purchases, external publication or live trading.

- P0 existing release/privacy and analytics gates remain first; differential replay of existing provider/Risk Engine behavior, stale/missing data and deterministic recommendations; no weakened tests or changed thresholds, independent reviewer.
- P2 AdvMMN research only: obtain full Scientific Reports paper and verify method/data/license, compare image+weather model with current provider and authoritative Spanish station observations on chronological/location holdouts; evaluate PM2.5/PM10/NO2/O3 MAE/bias, fog/light/humidity confounding, missing images, uncertainty and privacy. No claims of accuracy or medical advice, no change to deterministic Risk Engine. If full text unavailable, BLOCKED_RESEARCH.
- P1 coordinate three synthetic video versioning pilot with Growth Content Factory; no publication/experiment activation. Monitor GigaChat/Decision Models only; no deployment.

Delivery: separate implementation branch; gap matrix IMPLEMENTED/PARTIAL/MISSING/BLOCKED, unchanged tests plus negative/regression tests, exact SHA, reproducible commands/results, independent verdict, rollback and blockers. Never mark DONE from docs/build alone. Stop on missing authority or unsafe effects.

Sources for verification (digest candidates, not independently revalidated in this planning edit): https://www.anthropic.com/research/migrating-api-to-rust ; https://artificialanalysis.ai/decision-models/d1-3-ultra ; https://github.com/agentnativeinc/v2 ; https://v2.video/ ; https://huggingface.co/ai-sage/GigaAM-Multilingual-v2 ; https://github.com/salute-developers/GigaAM ; https://www.nature.com/articles/s41598-026-81611-w ; https://huggingface.co/ai-sage/GigaChat3.5-Omni-432B-A28B ; https://github.com/salute-developers/gigachat4 ; https://www.tomshardware.com/tech-industry/artificial-intelligence/sandboxed-ai-models-secretly-talk-via-gpu-rounding-errors-on-shared-vllm-servers-with-no-network-or-shared-files-colluding-watchdog-let-all-354-attacks-slip-through ; https://www.youtube.com/watch?v=TbKkN1cesTo ; https://www.youtube.com/watch?v=bFcob2p6u3A .
