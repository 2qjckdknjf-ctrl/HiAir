# План доработки (Phase 20) — выполнение без остановки

Цель: закрыть **INTERNAL_FIXABLE** без секретов и без косметического рефакторинга.

| # | Задача | Тип | Статус |
|---|--------|-----|--------|
| 1 | `datetime.utcnow()` → UTC-aware `datetime.now(UTC)` в `environment_service.py` | INTERNAL_FIXABLE | DONE |
| 2 | Logout: сброс локального push-state (iOS `push.lastRegistrationStatus`; Android prefs `hiair_push`) | INTERNAL_FIXABLE | DONE |
| 3 | Документация: security hardening + `10-fixes-applied` | INTERNAL_FIXABLE | DONE |
| 4 | Верификация: `pytest`, Android compile, iOS build | INTERNAL_FIXABLE | DONE |

**Не входит в этот проход (внешнее):** FCM SDK, TestFlight, Play, legal, live push — см. `19-deep-delta-audit.md`.

---

## Phase 21 (продолжение без остановки)

| # | Задача | Статус |
|---|--------|--------|
| 1 | `.gitignore`: `google-services.json`, `GoogleService-Info.plist` | DONE |
| 2 | `run_local_beta_smoke.sh`: подсказка как поднять API и повторить preflight | DONE |
| 3 | Док: `docs/mobile/ANDROID-FCM-LOCAL-INTEGRATION-STEPS.md` + `mobile/README.md` | DONE |
| 4 | `HIAIR-CLOSED-BETA-RC1-ARTIFACTS.md`: актуальный счётчик pytest | DONE |

## Phase 22 (FCM в репо, условно)

| # | Задача | Статус |
|---|--------|--------|
| 1 | Root Gradle: `google-services` apply false | DONE |
| 2 | App Gradle: при наличии JSON — plugin, deps, `src/firebase/java`, `FIREBASE_CONFIGURED` | DONE |
| 3 | `FcmFirebaseBootstrap` + `FcmTokenRefresher` + вызов из `PushTokenRegistrar` | DONE |
| 4 | `assembleDebug`, `lintDebug`, `assembleRelease`/`bundleRelease` без JSON | DONE |
| 5 | Док `ANDROID-FCM-LOCAL-INTEGRATION-STEPS.md` | DONE |
