# HiAir: Apple Developer + TestFlight (пошагово)

Дата: 2026-05-26  
Проект iOS: `mobile/ios`  
Bundle ID: `com.hiair.app`  
Team ID (уже в репо): `43A4KW5BKB`  
Текущий ship target: `1.0` (build `188` на redesign-ветке); последний подтверждённый Apple upload — build `181`  

> Важно: из Linux cloud VM загрузку в TestFlight не делаем. Для build `188` нужен **Mac + Xcode 26+** или **Xcode Cloud**.

---

## Фаза 0 — Что нужно заранее

| Требование | Где проверить |
|---|---|
| Apple Developer Program (оплачен) | https://developer.apple.com/account |
| Mac + Xcode **26+** (загрузка в ASC с апр. 2026) или **Xcode Cloud** | `xcodebuild -version`; см. `docs/release/XCODE_CLOUD_SETUP.md` |
| Доступ к App Store Connect | https://appstoreconnect.apple.com |
| Backend/Supabase для Release | `INFOPLIST_KEY_API_BASE_URL` = `https://api.hiair.io` (или staging URL) |

Локально уже есть **Apple Development** сертификат — этого достаточно для разработки; для TestFlight нужен **App Store distribution** (Xcode создаст автоматически при Upload).

---

## Фаза 1 — Apple Developer Portal (Identifiers)

Открой: https://developer.apple.com/account/resources/identifiers/list

### 1.1 App ID

1. **+** → **App IDs** → **App**.
2. Description: `HiAir`.
3. Bundle ID: **Explicit** → `com.hiair.app`.
4. Capabilities (включить):
   - **Sign in with Apple** (обязательно для кнопки в приложении)
   - **Push Notifications** (в приложении запрашиваются разрешения)
   - **HealthKit** (обязательно для Apple Health / шаги и пульс; без этого HiAir **не появится** в «Здоровье → Конфиденциальность → Приложения»)
5. Register.

### 1.2 Sign in with Apple (для Supabase OAuth)

1. В списке Identifiers открой `com.hiair.app` → **Sign in with Apple** → **Configure** → Save.
2. Создай **Services ID** (если ещё нет):
   - **+** → **Services IDs**
   - Identifier, например: `com.hiair.app.auth`
   - Enable **Sign in with Apple** → Configure:
     - Primary App ID: `com.hiair.app`
     - Domains: `qhxesaemlhzwbunpqjoo.supabase.co`
     - Return URLs: `https://qhxesaemlhzwbunpqjoo.supabase.co/auth/v1/callback`
3. Создай **Key** для Sign in with Apple:
   - **Keys** → **+** → Sign in with Apple → Download `.p8` (один раз).
   - Запиши **Key ID** и **Team ID** (`43A4KW5BKB`).

Эти значения понадобятся в Supabase (Фаза 4).

---

## Фаза 2 — App Store Connect (приложение)

Открой: https://appstoreconnect.apple.com/apps

### 2.1 Новое приложение

1. **+** → **New App**.
2. Platform: iOS.
3. Name: `HiAir`.
4. Primary language: English (U.S.) или Russian — по стратегии.
5. Bundle ID: `com.hiair.app`.
6. SKU: `hiair-ios` (любой уникальный).
7. User Access: Full Access.

Запиши **Apple ID приложения** (числовой) → в `backend/.env.local` как `APP_STORE_CONNECT_APP_ID`.

### 2.2 Метаданные (черновик)

Источник: `docs/release/store/APP_STORE_HANDOFF.md`, `PRIVACY_LABELS.md`, `REVIEWER_NOTES.md`.

Минимум перед TestFlight Internal:
- Privacy Policy URL (публичный https)
- Export compliance: обычно «No» для wellness без шифрования сверх стандартного HTTPS
- Content rights / age rating questionnaire

### 2.3 TestFlight

1. Вкладка **TestFlight** → дождись первого билда (после Фазы 5).
2. **Internal Testing** → создай группу `HiAir Core`.
3. Добавь тестеров (Apple ID email) — до 100 internal без review.

---

## Фаза 3 — Xcode: подпись и проект

```bash
cd /Users/alex/Projects/HIAir/mobile/ios
xcodegen
open HiAir.xcodeproj
```

В Xcode → target **HiAir** → **Signing & Capabilities**:

| Поле | Значение |
|---|---|
| Team | твоя команда (`43A4KW5BKB`) |
| Bundle Identifier | `com.hiair.app` |
| Signing | Automatically manage signing |

Проверь capabilities (должны совпасть с entitlements):
- Sign in with Apple
- Push Notifications

Увеличь **Build** перед архивом: target → General → **Build** `2`, `3`, …

---

## Фаза 4 — Supabase Auth (Apple + redirect)

Dashboard: https://supabase.com/dashboard/project/qhxesaemlhzwbunpqjoo/auth/providers

1. **URL Configuration** → Redirect URLs:
   - `hiair://auth/callback`
2. **Apple** provider:
   - Services ID: `com.hiair.app.auth` (из Фазы 1.2)
   - Secret Key: содержимое `.p8`
   - Key ID / Team ID из Apple
3. Сохрани и проверь email/password + Apple на устройстве.

Подробнее: `docs/_operator/supabase-auth-dashboard-setup.md`

---

## Фаза 5 — Сборка и загрузка в App Store Connect

### Вариант A — Xcode (рекомендуется первый раз)

1. Схема **HiAir**, устройство **Any iOS Device (arm64)**.
2. **Product → Archive** (Release).
3. Organizer → **Distribute App**:
   - **App Store Connect** → Upload
   - Automatically manage signing
4. Дождись «Upload Successful».

### Вариант B — CLI

```bash
cd /Users/alex/Projects/HIAir/mobile/ios
./scripts/archive_and_upload_testflight.sh
```

(Скрипт архивирует Release и экспортирует IPA; загрузка через `xcrun altool` / Transporter при наличии API key.)

Перед архивом из корня репо:

```bash
scripts/release/hiair_final_gate.sh
```

---

## Фаза 6 — TestFlight: тестеры и проверка

1. App Store Connect → TestFlight → билд в статусе **Processing** (15–40 мин).
2. Когда **Ready to Test** → Internal group → включи билд.
3. Тестеры получат приглашение в приложение **TestFlight**.

### Smoke на устройстве

- [ ] Установка из TestFlight
- [ ] Регистрация / вход (email)
- [ ] Sign in with Apple (если включён в Supabase)
- [ ] Dashboard / Planner / Insights / Symptoms
- [ ] Logout и повторный вход
- [ ] Privacy export/delete в Settings
- [ ] Push permission (если backend live)

Отчёт: `docs/release/qa/REAL_DEVICE_QA_REPORT.md`

---

## Частые ошибки

| Ошибка | Решение |
|---|---|
| No profiles for `com.hiair.app` | App ID в Developer Portal + Automatic Signing в Xcode |
| Sign in with Apple не работает | Services ID, Return URL в Apple + provider в Supabase |
| Upload failed: version/build duplicate | Увеличь **Build** в Xcode |
| Missing compliance | App Store Connect → TestFlight → ответь на export compliance |
| API не отвечает в Release | Проверь `INFOPLIST_KEY_API_BASE_URL` и что backend доступен по HTTPS |
| HiAir нет в «Здоровье → Приложения» | 1) Developer Portal → App ID `com.hiair.app` → **HealthKit** → Save. 2) Удалить старые provisioning profiles для `com.hiair.app` или дождаться новых от Xcode Cloud. 3) TestFlight build ≥ **11** (в Настройках HiAir виден номер сборки). 4) В HiAir → «Подключить Apple Health» — должен появиться системный запрос; если видите «сборка подписана без HealthKit» — профиль подписи без entitlement. 5) Проверка IPA: `bash scripts/ops/validate_ios_healthkit_ipa.sh path/to/HiAir.ipa`. |

---

## Следующий шаг после Internal TestFlight

- External TestFlight (нужен Beta App Review) или App Store Review.
- Скриншоты: `docs/release/store/SCREENSHOT_CHECKLIST.md`
- APNs production key для live push: `docs/05_RELEASE_READINESS.md`
