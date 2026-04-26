# HiAir mega Closed Beta GO / NO-GO (evidence-backed)

Decision date: **2026-04-26**  
Evidence source: `docs/audit/18-execution-ledger.md`, `docs/audit/11-verification-results.md`, local command outputs.

## Green gates (engineering, this machine)

| Gate | Command / artifact | Result |
| --- | --- | --- |
| Postgres | `pg_isready -h localhost -p 5432` | accepting connections |
| pytest | `cd backend && ../.venv/bin/python -m pytest -q` | `36 passed` |
| DB smoke helper | `PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh` | migrations + `smoke_db_flow` + retention + env strict + historical risk OK |
| API health | `curl http://127.0.0.1:8000/api/health` | `{"status":"ok",...}` |
| beta_preflight | `scripts/beta_preflight.py --base-url http://127.0.0.1:8000 --admin-token "$NOTIFICATION_ADMIN_TOKEN"` | `Preflight passed.` |
| iOS simulator | `xcodebuild … iphonesimulator … CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` |
| Android | `./gradlew clean assembleDebug assembleRelease bundleRelease lint` | `BUILD SUCCESSFUL` |
| Manifest | `python3 mobile/scripts/generate_release_manifest.py --strict` | AAB + xcarchive (+ IPA if exported) |

## Yellow gates (manual QA / external control)

| Gate | Why yellow | Owner action |
| --- | --- | --- |
| Real-device QA | Not executed in this automation | Run `docs/qa/HIAIR-RC1-REAL-DEVICE-QA-PACKET.md` |
| TestFlight | Needs Apple account + signed upload | `docs/release/IOS-TESTFLIGHT-RC-UPLOAD-STEPS.md` |
| Play Internal | Needs Console + signing | `docs/release/ANDROID-PLAY-INTERNAL-RC-UPLOAD-STEPS.md` |
| Push live | Needs FCM/APNs + device | `docs/release/FIREBASE-APNS-FCM-SETUP.md` |
| Ops | On-call / WAF evidence | `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md` |

## Red gates (legal / blocking product truth)

| Gate | Type |
| --- | --- |
| Privacy policy / terms public URLs | LEGAL_SIGNOFF_REQUIRED |
| App Store privacy labels + Play Data Safety | LEGAL_SIGNOFF_REQUIRED |

## Exact next owner actions (RU)

1. Подтвердить **beta owner** и **on-call**; заполнить чеклисты в `docs/ops/CLOSED-BETA-OPS-RUNBOOK.md`.
2. Пройти **TestFlight**: архив + экспорт IPA + загрузка; сохранить скриншоты ASC.
3. Пройти **Play Internal**: загрузить AAB, тестеры, Data Safety.
4. Настроить **Firebase/APNs/FCM** локально и в секрет-менеджере бэкенда; **не коммитить** `google-services.json`, APNs `.p8`, ключи FCM.
5. Юридически утвердить **Privacy Policy / Terms** и публичные URL для стора.
6. Выполнить **реальный девайс QA** по пакету в `docs/qa/`.
7. Перед новым билдом в стор: инкремент **iOS build number** и **Android versionCode** (`docs/release/VERSIONING-AND-BUILD-NUMBERS.md`).

## Evidence checklist (what to attach to a GO packet)

- [ ] Лог pytest (`36 passed`) и smoke helper (без секретов).
- [ ] `beta_preflight` вывод с `[OK]` и `Preflight passed.`
- [ ] `docs/release-artifacts-manifest.md` после `generate_release_manifest.py --rc` или `--strict`.
- [ ] Скриншоты ASC / Play (без секретов).
- [ ] Реджектированные логи push (`HiAirPush` / OSLog `push`) с успешной регистрацией токена.

## Final verdict table

| Area | Verdict | Evidence |
| --- | --- | --- |
| Backend smoke | **GO** | Smoke script OK with Postgres |
| API preflight | **GO** | `Preflight passed.` after uvicorn |
| iOS simulator | **GO** | `BUILD SUCCEEDED` |
| Android bundleRelease | **GO** | Gradle success |
| Push code | **NEAR-GO** | Compiles; logs + single endpoint; Android FCM writer still external |
| Push live | **BLOCKED_EXTERNAL** | No production credential/device proof |
| TestFlight | **BLOCKED_EXTERNAL** | Owner signing/upload |
| Google Play Internal | **BLOCKED_EXTERNAL** | Owner console/upload |
| Legal | **LEGAL_SIGNOFF_REQUIRED** | Drafts only |
| Ops | **BLOCKED_EXTERNAL** | Owner assignment |
| Real-device QA | **NEEDS_MANUAL_QA** | Scripts exist |
| Closed Beta (product) | **NEAR-GO** | Engineering green; yellow/red gates open |
| Public Launch | **NO-GO** | Legal + stores + ops not closed |

**No unconditional GO:** product Closed Beta remains **NEAR-GO** until yellow/red gates are closed with attached evidence.
