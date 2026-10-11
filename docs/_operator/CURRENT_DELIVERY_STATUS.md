# Текущее состояние доставки HiAir — 11 октября 2026

Код объединён в main через PR83. Production API работает на `833a06e48e3e2faf1c51719e3a3b5f59761736bd`; GitHub deployment 38130417768 завершён успешно. Post-deploy smoke с проверкой SHA/live AI и authenticated feature smoke прошли. Синтетический аккаунт удалён через privacy API. Последующие изменения PR84 касаются release workflow и исторических планов; backend/mobile runtime от production не отличается.

Рабочий каталог: `/Users/alex/Projects/HIAir-main` — постоянный чистый main. `/Users/alex/Projects/HIAir-integration` — временная интеграция. `/Users/alex/Projects/HIAir` — сохранённая legacy копия и общий Git storage; не начинать там разработку. 18 прежних worktrees перемещены в `/Users/alex/Projects/.hiair-archive/2026-10-11/worktrees`; snapshots и all-refs bundle сохранены отдельно. Их нельзя удалять до отдельного решения об очистке.

Последний план — `docs/roadmap/HIAIR_PLAN_AMENDMENT_2026-09-23.md`, включая дополнения 7 октября. PR73/PR81 сохранены как исторические документы, их старые очереди не заменяют актуальные task IDs. Voice, shared assurance, provider benchmark/ensemble/bias и knowledge research остаются отложенными. Forecast/Action/Travel/hazards/Health уже реализованы: сначала проверять существующий код и acceptance criteria, затем продолжать зарегистрированную задачу.

Перед работой: `git fetch origin`, затем `python3 scripts/ops/task_preflight.py --task <ID> --resume`. Для новой реализации сначала проверить реестр и PR, зарегистрировать новый ID. Одна задача — одна ветка от свежего main — один PR. Завершение отдельно фиксирует merge, deploy, artifact и device/store evidence; папка или закрытый PR сами по себе не доказывают доставку.

Проверки кандидата `3c15a9c5`: backend 485 тестов PASS, coverage 76.19%; iOS 230 unit PASS; Android 122 unit и lint PASS; pip-audit PASS. Phone/iPad simulator UI проверки прошли. Подписанные артефакты, SHA256, source/merged/deployed SHA и store receipts находятся в `docs/release/RELEASE_MANIFEST_2026-10-11.json`.

Android 1.2.0 code 300 загружен в Google Play internal, edit commit SUCCESS (run 38130939253). iOS 1.2 build 300 принят Apple: VALID / IN_BETA_TESTING. На физическом iPhone 17 Pro установка, запуск, восстановление существующей сессии и загрузка live dashboard PASS. Полная physical/device/IAP матрица ещё не подтверждена; физического Android нет. Публичный App Store/Play release не выполнялся. HIAIR-REL-001 сохраняет незакрытые device/store AC; HIAIR-PRED-002 — delivered baseline, но измеримое улучшение качества требует отдельной проверки AC. Не объявлять весь roadmap завершённым по наличию сборки.

Production security: account_deletion_operations/account_deletion_stage_events имеют RLS, клиентские grants отозваны, серверный доступ проверен. Main защищён обязательными backend/android/iOS checks, актуальной базой и разрешением review threads. CI отменяет superseded runs; Xcode Cloud запускает архивирование только release/*.
