# Архитектура MVP (по шагам из PDF)

## Компоненты системы

- Mobile client (iOS/Android).
- Backend API (единый сервис на этапе MVP).
- Сервис ingestion внешних источников (weather + AQI).
- Rule-based risk engine.
- Notification service (FCM/APNs).
- PostgreSQL (или другой выбранный storage).

## Логические модули backend

- `auth` - регистрация, логин, токены.
- `profiles` - персональные профили и чувствительность.
- `environment` - получение и нормализация погодных и air-quality данных.
- `risk` - расчет risk score и генерация рекомендаций.
- `symptoms` - хранение и чтение symptom logs.
- `notifications` - правила, расписание, отправка push.

## Актуальный статус реализации (дополнение)

Фактический backend уже расширен относительно базовой MVP-схемы выше:
- активны отдельные роутеры `air`, `alerts`, `subscriptions`, `privacy`, `observability`, `thresholds`, `validation`;
- coexist legacy и new risk paths (`/api/risk/*` и `/api/air/*`);
- в БД присутствуют расширенные таблицы AI/alerts/risk-assessments.

Этот документ остается high-level архитектурным baseline; текущее truth-состояние и gap-карта ведутся в `docs/_operator/*`.

## Черновая модель данных

### `users`
- id, email, password_hash, created_at

### `profiles`
- id, user_id, persona_type, sensitivity_level, home_lat, home_lon

### `environment_snapshots`
- id, region_key, timestamp_utc, temperature_c, humidity_percent, aqi, pm25, ozone

### `symptom_logs`
- id, profile_id, timestamp_utc, cough, wheeze, headache, fatigue, sleep_quality

### `risk_scores`
- id, profile_id, snapshot_id, score_value, risk_level, recommendations_json, created_at

## Risk score v1

`score = env_component + persona_modifier + symptom_modifier`

- `env_component`: heat index, AQI, PM2.5, ozone.
- `persona_modifier`: надбавка для child/elderly/asthma/allergy.
- `symptom_modifier`: надбавка при недавних симптомах.

## Безопасность и комплаенс (MVP baseline)

- TLS/HTTPS для всего трафика.
- Современный password hashing.
- Минимизация данных и явные consent flows.
- Удаление данных пользователя по запросу.
- Формулировки в продукте: wellness guidance, not medical advice.
