# Google Play Handoff

**Updated:** 2026-08-21  
**Identity target:** iOS **1.0 (188)** / Android **1.0 (188)**  
**Application ID:** `com.hiair`  
**Do not publish production** until the owner verifies.

## Listing Metadata (en-US)

- App name: HiAir
- Short description (≤80): `Air quality & heat day planner for safer outdoor time.`
- Full description:

```
HiAir helps you understand outdoor heat and air quality for your day. See personal risk guidance, safe windows to go outside, and simple next steps—wellness information, not medical advice.

• Live or cached air + heat risk for your area
• Daily planner with safer outdoor windows
• Private symptom journal (not social sharing)
• Optional Health Connect daily aggregates
• Premium insights, extra profiles, and alerts

HiAir Premium auto-renews until you cancel. Payment is charged to your Google Play account. Manage or cancel in Google Play → Subscriptions.

HiAir Premium Monthly — 1 month
HiAir Premium Yearly — 1 year

Terms of Use: https://hiair.io/terms/
Privacy Policy: https://hiair.io/privacy/
Support: hello@hiair.io

Accounts are for users 13+. HiAir is not a medical device and does not diagnose, treat, or provide emergency care.
```

- Category: Health & Fitness
- Contact: hello@hiair.io / https://hiair.io
- Privacy: https://hiair.io/privacy/

## Listing Metadata (ru-RU)

- Short description: `Планировщик воздуха и жары на день.`
- Full description:

```
HiAir помогает понять жару и качество воздуха на день. Персональный риск, безопасные окна для прогулки и понятные шаги — wellness-подсказки, не медицинский совет.

• Живые или кэшированные данные воздуха и жары
• План дня с более безопасными окнами на улице
• Личный дневник симптомов (без публичной ленты)
• Опциональные дневные агрегаты Health Connect
• Premium: инсайты, профили и оповещения

HiAir Premium продлевается автоматически, пока вы не отмените. Оплата списывается с аккаунта Google Play. Управление: Play → Подписки.

HiAir Premium Monthly — 1 месяц
HiAir Premium Yearly — 1 год

Условия: https://hiair.io/terms/
Конфиденциальность: https://hiair.io/privacy/
Поддержка: hello@hiair.io

Аккаунт только для 13+. HiAir не является медицинским изделием, не ставит диагнозы и не заменяет неотложную помощь.
```

## Binary

- versionName: `1.0` (matches iOS marketing version)
- versionCode: `188` (matches iOS build 188)
- Signing: `mobile/android/keystore.properties` (gitignored)
- Release API: `https://api.hiair.io`
- Subscriptions: `hiair_premium_monthly` / `hiair_premium_yearly` (ACTIVE)

## Data Safety Draft

See `docs/release/store/DATA_SAFETY.md`.

## Content Rating Notes

- Non-violent, non-sexual, non-gambling.
- Health/wellness guidance only; not emergency/diagnostic software.
- Target age: 13+ (not designed for children).

## Testing Track Checklist

- [x] Internal testing track historically live (182).
- [ ] Internal 188 signed AAB uploaded.
- [ ] License testers can purchase Premium.
- [ ] Validate login/Google OAuth/session refresh/logout.
- [ ] Validate notification permission flow on Android 13+.
- [ ] Validate Health Connect Continue pre-prompt (no Skip).
- [ ] Validate release build with HTTPS API endpoint.

## App Access Notes

Provide review credentials in Play Console App access (do not commit the password):

- Email: value from `APP_REVIEW_TEST_EMAIL` in `backend/.env.local`
- Password: `APP_REVIEW_TEST_PASSWORD`

Reviewer path: Log in (primary) → Register secondary → Google via Custom Tabs (`hiair://auth/callback`). Dashboard, Planner, Insights, Symptoms, Settings Restore / Manage subscription / hello@hiair.io / Terms / Privacy. Paywall shows Monthly/Yearly title, length, Play price.

## Questionnaires still required in Console

See `docs/release/store/PLAY_CONSOLE_QUESTIONNAIRES.md`.

## External Blockers

- Owner verification before production track.
- Play Console questionnaires (content rating, target audience, data safety, advertising ID, health apps).
- Android Deep Glass screenshot recapture (existing Play screenshots are from 2026-08-11, pre-v4).
- Target API 36 required for new Play updates after 2026-08-31 (current binary is API 35, valid until that date).
