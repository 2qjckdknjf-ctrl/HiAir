# HiAir Roadmap (из файла "Идеи для вирусных приложений.pdf")

## Phase 1 - Research and Planning

- Анализ heat-wave и air-quality трендов и влияния на здоровье.
- Определение целевых персон.
- Competitive analysis существующих приложений (weather/AQI/health).
- Выбор и оценка API (точность, задержка, покрытие, стоимость, лицензии).
- Определение формулы risk score (экология + персональные факторы).
- Исследование HealthKit/Health Connect возможностей и permission model.
- Регуляторный контур: EU MDR, FDA wellness guidance, GDPR/CCPA.
- Выбор технологического стека и проектной инфраструктуры.
- Проработка архитектуры и UX (онбординг, dashboard, planner, symptoms, settings).

## Phase 2 - MVP Development

- Data ingestion и нормализация environmental data.
- Rule-based risk scoring engine.
- User management endpoints и профили.
- Notification service (FCM/APNs).
- Mobile-функции MVP: onboarding, dashboard, planner, symptom log, settings.
- Алгоритмическая валидация на исторических данных.
- CI/CD, staging/prod, мониторинг.

## Phase 3 - Beta Testing and Launch Preparation

- Закрытая бета через TestFlight и Google Play Internal Test.
- Мониторинг crash/latency и исправление багов.
- Cross-device QA и локализация.
- Privacy/compliance аудит и финальные legal документы.
- Pre-launch маркетинг: landing page, контент, партнерства.

## Phase 4 - Public Launch and Growth

- Публикация в сторы и сопровождение модерации.
- Запуск в первичном рынке (Spain/EU в исходном плане).
- Метрики engagement/retention, оптимизация push-контента.
- Масштабирование инфраструктуры и поддержка пользователей.

## Phase 5 - Wearable Integration and Premium

- Интеграция HealthKit/Health Connect.
- Расширение risk-модели физиологическими сигналами.
- UI инсайтов по wearable + environment.
- Подписка: multi-profile, extended forecast, custom alerts, reports.

## Phase 6 - Advanced Features and Expansion

- Smart-home/indoor integrations (термостаты, очистители, сенсоры).
- Community/social и UGC с модерацией.
- ML predictive models на агрегированных данных.
- B2B инструменты для работодателей/школ/организаций.
- Международная локализация и адаптация под разные климатические регионы.
- Непрерывный мониторинг регуляторных изменений.
