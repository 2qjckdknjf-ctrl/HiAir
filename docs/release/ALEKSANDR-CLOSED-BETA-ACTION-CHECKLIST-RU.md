# Что Александру нужно сделать для запуска HiAir Closed Beta

## Шаг 1 - Backend

- Запусти локальный PostgreSQL, если он еще не запущен:

```bash
brew services stop postgresql@16 || true
mkdir -p ~/.hiair
[ -s ~/.hiair/postgres-data/PG_VERSION ] || LC_ALL=C initdb -D ~/.hiair/postgres-data
LC_ALL=C pg_ctl -D ~/.hiair/postgres-data -l ~/.hiair/postgres.log start
pg_isready -h localhost -p 5432
```

- Проверь backend smoke:

```bash
cd backend
PYTHON_BIN=../.venv/bin/python ./scripts/run_local_beta_smoke.sh
```

- Ожидаемый результат: Postgres reachable, migrations/init DONE, smoke_db_flow DONE, retention dry-run DONE, env strict DONE, historical risk validation DONE.

## Шаг 2 - Apple Developer

- Открой Apple Developer.
- Проверь, что аккаунт enrolled в Apple Developer Program.
- Открой Certificates, Identifiers & Profiles.
- Создай или подтверди Bundle ID `com.hiair.app`.
- Включи Push Notifications для Bundle ID.
- Сохрани evidence: screenshot Bundle ID и включенной Push Notifications capability.
- Запиши Apple Team ID в приватный менеджер паролей, не в git.

## Шаг 3 - TestFlight

- Открой App Store Connect.
- Создай app record для HiAir, если его еще нет.
- Заполни SKU, support URL, privacy URL и beta contact.
- В Xcode открой `mobile/ios/HiAir.xcodeproj`.
- Выбери Apple Team для target HiAir.
- Собери archive:

```bash
cd mobile/ios
xcodebuild -project HiAir.xcodeproj -scheme HiAir -configuration Release -destination generic/platform=iOS -archivePath build/HiAir.xcarchive archive
```

- Создай `ExportOptions.plist`:

```bash
cp ExportOptions.plist.template ExportOptions.plist
```

- Замени `REPLACE_WITH_APPLE_TEAM_ID` на реальный Team ID локально.
- Экспортируй IPA:

```bash
xcodebuild -exportArchive -archivePath build/HiAir.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

- Загрузи build через Xcode Organizer или Transporter.
- В TestFlight создай internal testing group и добавь тестеров.
- Сохрани evidence: archive/export success, build processing, internal group, tester access.

## Шаг 4 - Google Play Console

- Открой Google Play Console.
- Создай app для HiAir или открой существующий.
- Подтверди package/application ID: `com.hiair`.
- Выбери Play App Signing strategy.
- Не коммить keystore, passwords или upload-key secrets.
- Загрузи AAB:

```text
mobile/android/app/build/outputs/bundle/release/app-release.aab
```

- Открой Testing -> Internal testing.
- Создай release, добавь release notes, tester emails и opt-in link.
- Заполни Data Safety, content rating и privacy policy URL.
- Сохрани evidence: AAB uploaded, tester list, Data Safety, content rating, internal release active.

## Шаг 5 - Firebase/APNs/FCM

- Открой Firebase Console.
- Создай Firebase project для HiAir beta или открой существующий.
- Добавь Android app с package `com.hiair`.
- Скачай `google-services.json`, но не клади его в git.
- Добавь iOS app с Bundle ID `com.hiair.app`.
- В Apple Developer создай или выбери APNs key/cert.
- Загрузи APNs key/cert в Firebase Cloud Messaging.
- Храни APNs private key, Team ID, Key ID и Firebase secrets только в приватном secret manager.
- Проверь на реальных устройствах: APNs token upload, FCM token upload, delivered push.

## Шаг 6 - Legal/Store

- Передай юристу Privacy Policy, Terms, GDPR controller/contact, DSAR channel.
- Получи финальные URL:
  - Privacy Policy URL;
  - Terms URL;
  - Support URL.
- Заполни App Store privacy labels.
- Заполни Google Play Data Safety.
- Не отправляй external/public beta без legal signoff.
- Сохрани evidence: approved URLs, App Store privacy labels, Google Play Data Safety, legal approval.

## Шаг 7 - Ops

- Назначь beta owner.
- Назначь on-call owner.
- Создай support channel для beta testers.
- Определи rollback owner и rollback steps.
- Проверь WAF/rate limiting перед интернет-доступом к beta backend.
- Запланируй daily beta review на первые дни beta.
- Сохрани evidence: owners, channel, WAF/rate limiting screenshot/config, rollback plan.

## Финальный GO

| Gate | Done? | Evidence |
| ---- | ----- | -------- |
| Backend smoke | no | `run_local_beta_smoke.sh` output |
| API preflight | no | `Preflight passed.` output |
| iOS archive | yes | `mobile/ios/build/HiAir.xcarchive` |
| iOS IPA | yes | `mobile/ios/build/HiAir.ipa` |
| TestFlight internal | no | App Store Connect/TestFlight screenshot |
| Android AAB | no | `mobile/android/app/build/outputs/bundle/release/app-release.aab` |
| Google Play Internal | no | Play Console internal release screenshot |
| APNs/FCM live push | no | device push screenshot and backend logs |
| Legal signoff | no | approved privacy/terms/store forms |
| Ops readiness | no | owner/channel/WAF/rollback evidence |
| Real-device QA | no | completed `docs/qa/HIAIR-RC1-REAL-DEVICE-QA-PACKET.md` |
