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
- [x] Внедрена versioned deprecation-политика для risk alias (`medium`/`moderate`) с `warn/enforce` режимами и migration headers.
- [x] Добавлен автоматический gate `check_store_metadata_packet.py` для контроля полноты store packet (чекбоксы + placeholders).
- [ ] Закрытая бета (TestFlight + Google Play Internal Test).
- [ ] QA по устройствам/версиям ОС (по чеклисту).
- [ ] Privacy/ToS финализация (drafts готовы, требуется legal review).
- [ ] Прелендинг и ранние регистрации.

## Следующий исполняемый шаг

1. Загрузить готовые артефакты в TestFlight/Internal Test (нужны доступы Apple/Google).
2. Выполнить `docs/qa-checklist.md` на iOS/Android и зафиксировать баги по шаблону.
