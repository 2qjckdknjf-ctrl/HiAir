import Foundation

@MainActor
final class AppSession: ObservableObject {
    private enum Keys {
        static let onboardingCompleted = "session.onboardingCompleted"
        static let checklistCompletedItems = "session.checklistCompletedItems"
        static let checklistHidden = "session.checklistHidden"
        static let userId = "session.userId"
        static let accessToken = "session.accessToken"
        static let refreshToken = "session.refreshToken"
        static let profileId = "session.profileId"
        static let persona = "session.persona"
        static let sensitivity = "session.sensitivity"
        static let preferredLanguage = "session.preferredLanguage"
        static let latitude = "session.latitude"
        static let longitude = "session.longitude"
    }

    @Published var onboardingCompleted = false { didSet { persist() } }
    @Published var userId = "" { didSet { persist() } }
    @Published var accessToken = "" { didSet { persist() } }
    @Published var refreshToken = "" { didSet { persist() } }
    @Published var authNotice = ""
    @Published var profileId = "" { didSet { persist() } }
    @Published var persona = "adult" { didSet { persist() } }
    @Published var sensitivity = "medium" { didSet { persist() } }
    @Published var preferredLanguage = "ru" { didSet { persist() } }
    @Published var latitude = 41.39 { didSet { persist() } }
    @Published var longitude = 2.17 { didSet { persist() } }
    @Published var checklistCompletedItems: Set<String> = [] { didSet { persist() } }
    @Published var checklistHidden = false { didSet { persist() } }
    @Published var showOnboardingFromSettings = false
    @Published var selectedTab = 0
    private let apiClient = APIClient.live()

    init() {
        let defaults = UserDefaults.standard
        onboardingCompleted = defaults.object(forKey: Keys.onboardingCompleted) as? Bool ?? false
        userId = defaults.string(forKey: Keys.userId) ?? ""
        accessToken = defaults.string(forKey: Keys.accessToken) ?? ""
        refreshToken = defaults.string(forKey: Keys.refreshToken) ?? ""
        profileId = defaults.string(forKey: Keys.profileId) ?? ""
        persona = defaults.string(forKey: Keys.persona) ?? "adult"
        sensitivity = defaults.string(forKey: Keys.sensitivity) ?? "medium"
        preferredLanguage = defaults.string(forKey: Keys.preferredLanguage) ?? "ru"
        latitude = defaults.object(forKey: Keys.latitude) as? Double ?? 41.39
        longitude = defaults.object(forKey: Keys.longitude) as? Double ?? 2.17
        checklistCompletedItems = Set(defaults.stringArray(forKey: Keys.checklistCompletedItems) ?? [])
        checklistHidden = defaults.object(forKey: Keys.checklistHidden) as? Bool ?? false
        APIClient.setAuthInvalidatedHandler { [weak self] in
            Task { @MainActor in
                self?.expireSessionAfterAuthFailure()
            }
        }
        if userId.isEmpty || accessToken.isEmpty || refreshToken.isEmpty {
            APIClient.setAuthState(nil)
        } else {
            APIClient.setAuthState(
                APIClient.AuthState(
                    userId: userId,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            )
        }
    }

    func logout() {
        userId = ""
        accessToken = ""
        refreshToken = ""
        authNotice = ""
        profileId = ""
        selectedTab = 0
        APIClient.setAuthState(nil)
    }

    func markChecklistItem(_ id: String, done: Bool) {
        if done {
            checklistCompletedItems.insert(id)
        } else {
            checklistCompletedItems.remove(id)
        }
    }

    func isChecklistItemDone(_ id: String) -> Bool {
        checklistCompletedItems.contains(id)
    }

    func resetChecklist() {
        checklistCompletedItems = []
        checklistHidden = false
    }

    func finishOnboarding() {
        onboardingCompleted = true
        checklistHidden = false
    }

    func expireSessionAfterAuthFailure() {
        guard !(userId.isEmpty && accessToken.isEmpty) else {
            return
        }
        userId = ""
        accessToken = ""
        refreshToken = ""
        profileId = ""
        selectedTab = 0
        authNotice = l("auth.session_expired")
        APIClient.setAuthState(nil)
    }

    func ensureProfileIdIfNeeded() async -> Bool {
        if !profileId.isEmpty {
            return true
        }
        guard !userId.isEmpty, !accessToken.isEmpty else {
            return false
        }
        do {
            let profiles = try await apiClient.listProfiles(userId: userId, accessToken: accessToken)
            if let existing = profiles.first {
                profileId = existing.id
                return true
            }
            let created = try await apiClient.createProfile(
                userId: userId,
                payload: ProfileCreatePayload(
                    personaType: persona,
                    sensitivityLevel: sensitivity,
                    homeLat: latitude,
                    homeLon: longitude
                ),
                accessToken: accessToken
            )
            profileId = created.id
            return true
        } catch {
            return false
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted)
        defaults.set(userId, forKey: Keys.userId)
        defaults.set(accessToken, forKey: Keys.accessToken)
        defaults.set(refreshToken, forKey: Keys.refreshToken)
        defaults.set(profileId, forKey: Keys.profileId)
        defaults.set(persona, forKey: Keys.persona)
        defaults.set(sensitivity, forKey: Keys.sensitivity)
        defaults.set(preferredLanguage, forKey: Keys.preferredLanguage)
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
        defaults.set(Array(checklistCompletedItems).sorted(), forKey: Keys.checklistCompletedItems)
        defaults.set(checklistHidden, forKey: Keys.checklistHidden)
        if userId.isEmpty || accessToken.isEmpty || refreshToken.isEmpty {
            APIClient.setAuthState(nil)
        } else {
            APIClient.setAuthState(
                APIClient.AuthState(
                    userId: userId,
                    accessToken: accessToken,
                    refreshToken: refreshToken
                )
            )
        }
    }
}

enum HiAirL10n {
    static func t(_ key: String, lang: String) -> String {
        let language = lang.lowercased().hasPrefix("en") ? "en" : "ru"
        return strings[language]?[key] ?? strings["ru"]?[key] ?? key
    }

    private static let strings: [String: [String: String]] = [
        "ru": [
            "title.settings": "Настройки",
            "tab.dashboard": "Главная",
            "tab.planner": "План",
            "tab.insights": "Инсайты",
            "insights.empty": "Логируй симптомы, чтобы открыть персональные паттерны.",
            "insights.unlock_more": "Логируй еще 5 дней, и появятся паттерны.",
            "insights.failed": "Не удалось загрузить инсайты.",
            "insights.count": "инсайтов",
            "insights.loading": "Загружаем персональные паттерны...",
            "insights.retry": "Попробовать снова",
            "settings.briefing_setup_hint": "Сначала войди в аккаунт, чтобы настроить Morning Briefing.",
            "tab.symptoms": "Симптомы",
            "tab.settings": "Настройки",
            "auth.title": "Аккаунт HiAir",
            "auth.email": "Email",
            "auth.password": "Пароль (мин. 12 символов, A/a/0-9/символ)",
            "auth.sign_up": "Регистрация",
            "auth.signing_up": "Регистрируем...",
            "auth.log_in": "Войти",
            "auth.logging_in": "Входим...",
            "auth.enter_email": "Введите email.",
            "auth.password_short": "Пароль должен быть не короче 12 символов.",
            "auth.session_expired": "Сессия истекла. Войдите снова.",
            "auth.ok": "Авторизация успешна.",
            "auth.email_conflict": "Пользователь с таким email уже существует.",
            "auth.backend_unreachable": "Нет подключения к API. Проверьте, что backend запущен на 127.0.0.1:8000.",
            "auth.backend_unavailable": "Backend временно недоступен. Проверьте подключение к базе данных.",
            "auth.fail": "Ошибка авторизации.",
            "onboarding.title": "Онбординг HiAir",
            "onboarding.persona": "Профиль",
            "onboarding.sensitivity": "Чувствительность",
            "onboarding.latitude": "Широта",
            "onboarding.longitude": "Долгота",
            "onboarding.profile_id": "Profile ID (необязательно)",
            "onboarding.continue": "Продолжить",
            "onboarding.next": "Далее",
            "onboarding.back": "Назад",
            "onboarding.start": "Начать",
            "onboarding.step1.title": "HiAir — помощник по жаре и качеству воздуха",
            "onboarding.step1.body": "HiAir помогает понять, когда жара и воздух на улице могут быть небезопасны именно для вас.",
            "onboarding.step2.title": "Какие проблемы решает HiAir",
            "onboarding.problem.heat": "Жара и риск перегрева",
            "onboarding.problem.pm25": "Плохой воздух и PM2.5",
            "onboarding.problem.ozone": "Озон, дым и загрязнение",
            "onboarding.problem.sensitive": "Дети, пожилые, астма и аллергия",
            "onboarding.problem.outdoor": "Спорт, прогулки и работа на улице",
            "onboarding.step3.title": "Для кого вы используете HiAir?",
            "onboarding.for_self": "Для себя",
            "onboarding.for_child": "Для ребёнка",
            "onboarding.for_elderly": "Для пожилого человека",
            "onboarding.for_asthma": "Астма / дыхание",
            "onboarding.for_allergy": "Аллергия",
            "onboarding.for_runner": "Бег / спорт",
            "onboarding.for_worker": "Работа на улице",
            "onboarding.step4.title": "Что смотреть каждый день",
            "onboarding.look.risk": "Risk Score показывает общий риск сейчас",
            "onboarding.look.hourly": "Прогноз по часам показывает безопасные окна",
            "onboarding.look.recommendations": "Рекомендации объясняют, что делать",
            "onboarding.look.notifications": "Уведомления предупреждают заранее",
            "onboarding.step5.title": "Почему нужны разрешения",
            "onboarding.permissions.location.title": "Геолокация",
            "onboarding.permissions.location.body": "Геолокация нужна, чтобы считать риск по вашему району.",
            "onboarding.permissions.notifications.title": "Уведомления",
            "onboarding.permissions.notifications.body": "Уведомления нужны, чтобы предупредить о жаре или плохом воздухе заранее.",
            "onboarding.permissions.allow": "Разрешить",
            "onboarding.permissions.later": "Настроить позже",
            "onboarding.step6.title": "Готово",
            "onboarding.step6.body": "Теперь откройте главный экран, посмотрите текущий риск, рекомендации и безопасные часы на сегодня.",
            "onboarding.open_forecast": "Открыть мой прогноз",
            "dashboard.title": "Ежедневный воздушный интеллект",
            "common.city_updated": "Barcelona • Обновлено 2 мин назад",
            "dashboard.subtitle": "Риск, алерты и AI-инсайты в одном месте.",
            "dashboard.greeting": "Доброе утро, Alex",
            "dashboard.improving": "Качество воздуха улучшается. Планируйте прогулку после 16:30.",
            "dashboard.current_risk": "Текущий риск",
            "dashboard.current_risk_title": "Текущий риск",
            "dashboard.badge_moderate": "УМЕРЕННЫЙ",
            "dashboard.reason_code": "Жара + озон формируют текущий риск.",
            "dashboard.tomorrow_hint": "Завтра риск вероятно вырастет на 6 пунктов из-за скачка влажности.",
            "dashboard.location": "Barcelona",
            "dashboard.freshness_fresh": "свежее",
            "dashboard.freshness_stale": "обновить",
            "dashboard.profile_button": "Профиль",
            "dashboard.no_safe_window": "Нет безопасных окон в ближайшие часы.",
            "dashboard.error": "Не удалось загрузить данные.",
            "dashboard.empty.no_profile.title": "Профиль не настроен",
            "dashboard.empty.no_profile.body": "Без профиля невозможно персонально рассчитать риск и безопасные окна.",
            "dashboard.empty.no_profile.cta": "Создать профиль автоматически",
            "dashboard.empty.api_unavailable": "Данные временно недоступны. Проверьте интернет и попробуйте снова.",
            "dashboard.empty.location_missing": "Геолокация не задана. Укажите район в onboarding или настройках.",
            "dashboard.recommended_actions": "Рекомендуемые действия",
            "dashboard.no_actions": "Нет доступных действий.",
            "dashboard.safe_window": "Безопасное окно",
            "dashboard.safe_windows": "Безопасные окна",
            "dashboard.safe_windows_tooltip": "Период дня, когда условия более безопасны для прогулки, спорта или проветривания.",
            "dashboard.auto_updates": "Автообновление по прогнозу",
            "dashboard.do_now": "Сделать сейчас",
            "dashboard.recommendations_tooltip": "Персональные советы на основе текущего риска и вашего профиля.",
            "dashboard.action_1": "Избегайте активности с 10:00 до 15:00",
            "dashboard.action_2": "Пейте воду каждые 45 минут",
            "dashboard.action_3": "Лучшая прогулка: 16:30 - 19:00",
            "dashboard.recompute": "Пересчитать риск сейчас",
            "dashboard.log_symptoms": "Записать симптомы",
            "dashboard.loading": "Загрузка...",
            "dashboard.get_started.title": "С чего начать",
            "dashboard.get_started.hide": "Скрыть",
            "dashboard.get_started.item.risk": "Посмотрите текущий уровень риска",
            "dashboard.get_started.item.hourly": "Откройте прогноз по часам",
            "dashboard.get_started.item.recommendations": "Прочитайте рекомендации",
            "dashboard.get_started.item.profile": "Настройте профиль",
            "dashboard.get_started.item.notifications": "Включите уведомления",
            "dashboard.air_metrics": "Показатели воздуха",
            "dashboard.metric.aqi": "AQI",
            "dashboard.metric.pm25": "PM2.5",
            "dashboard.metric.ozone": "Озон",
            "dashboard.metric.heat_index": "Heat Index",
            "dashboard.metric.humidity": "Влажность",
            "dashboard.tooltip.risk_score": "Общая оценка риска для вас на основе жары, влажности и качества воздуха.",
            "dashboard.tooltip.aqi": "Индекс качества воздуха. Чем выше значение, тем хуже воздух.",
            "dashboard.tooltip.pm25": "Мелкие частицы загрязнения воздуха, которые могут раздражать лёгкие.",
            "dashboard.tooltip.ozone": "Озон у земли может ухудшать дыхание, особенно в жаркие дни.",
            "dashboard.tooltip.heat_index": "Ощущаемая температура с учётом влажности.",
            "planner.title": "План дня",
            "planner.subtitle": "Полный план на основе профиля и качества воздуха.",
            "planner.safe_windows": "Безопасные окна",
            "planner.ventilation_windows": "Окна проветривания",
            "planner.hourly_risk": "Риск по часам",
            "planner.hourly": "Почасово",
            "planner.refresh": "Обновить план",
            "planner.apply": "Применить план",
            "planner.loading": "Загрузка...",
            "planner.profile_required": "Нужен Profile ID.",
            "planner.fetch": "Загрузите план дня, чтобы увидеть ключевой интервал.",
            "planner.failed": "Не удалось загрузить план.",
            "planner.empty.no_profile.title": "Профиль пока не настроен",
            "planner.empty.no_profile.body": "Без профиля HiAir не может рассчитать персональные безопасные окна.",
            "planner.empty.no_profile.cta": "Создать профиль автоматически",
            "planner.empty.unavailable.title": "Прогноз временно недоступен",
            "planner.empty.unavailable.body": "Проверьте интернет или попробуйте снова через минуту.",
            "symptoms.title": "Журнал симптомов",
            "symptoms.subtitle": "Отмечайте самочувствие для точных персональных рекомендаций.",
            "symptoms.streak": "Серия: 4 дня подряд",
            "symptoms.profile_id": "Profile ID",
            "symptoms.cough": "Кашель",
            "symptoms.wheeze": "Свистящее дыхание",
            "symptoms.headache": "Головная боль",
            "symptoms.fatigue": "Усталость",
            "symptoms.sleep_quality": "Качество сна",
            "symptoms.quick_intensity": "Интенсивность (быстро)",
            "symptoms.quick_breath": "Быстро: Дыхание",
            "symptoms.quick_headache": "Быстро: Голова",
            "symptoms.save": "Сохранить симптомы",
            "symptoms.submit": "Отправить симптомы",
            "symptoms.saving": "Сохраняем...",
            "symptoms.saved_at": "Сохранено в",
            "symptoms.save_failed": "Не удалось сохранить симптомы.",
            "symptoms.quick_saved": "Быстрый симптом сохранён.",
            "symptoms.quick_failed": "Не удалось сохранить быстрый симптом.",
            "symptoms.empty.title": "Журнал симптомов пока пуст",
            "symptoms.empty.body": "Добавьте первый симптом, чтобы HiAir точнее подбирал рекомендации.",
            "settings.ai_observability": "AI наблюдаемость",
            "settings.subtitle": "Управляйте уведомлениями, подпиской и AI-наблюдаемостью.",
            "settings.notifications": "Уведомления",
            "settings.push": "Включить push-уведомления",
            "settings.morning_briefing": "Morning Briefing",
            "settings.morning_briefing_time": "Время брифинга (HH:MM)",
            "settings.morning_briefing_hint": "Персональная сводка каждое утро.",
            "settings.profile_alerting": "Алерты с учетом профиля",
            "settings.alert_threshold": "Порог алерта",
            "settings.threshold_medium": "Средний",
            "settings.threshold_high": "Высокий",
            "settings.threshold_very_high": "Очень высокий",
            "settings.quiet_start": "Тихие часы: начало",
            "settings.quiet_end": "Тихие часы: конец",
            "settings.profile_defaults": "Профиль по умолчанию",
            "settings.persona": "Персона",
            "settings.persona_adult": "Взрослый",
            "settings.persona_child": "Ребенок",
            "settings.persona_elderly": "Пожилой",
            "settings.persona_asthma": "Астма",
            "settings.persona_allergy": "Аллергия",
            "settings.persona_runner": "Бегун",
            "settings.persona_worker": "Рабочий на улице",
            "settings.language": "Язык",
            "settings.language_ru": "Русский",
            "settings.language_en": "English",
            "settings.window_24h": "24ч",
            "settings.window_72h": "72ч",
            "settings.sync": "Синхронизация",
            "settings.loading": "Загрузка...",
            "settings.saving": "Сохраняем...",
            "settings.subscription": "Подписка",
            "settings.security_privacy": "Безопасность и приватность",
            "settings.plan": "План",
            "settings.status": "Статус",
            "settings.sync_now": "Сохранить настройки и синхронизировать",
            "settings.advanced_controls": "Расширенные параметры графика",
            "settings.load": "Загрузить настройки",
            "settings.save": "Сохранить настройки",
            "settings.load_plans": "Загрузить планы",
            "settings.load_subscription": "Загрузить подписку",
            "settings.activate_subscription": "Активировать подписку",
            "settings.cancel_subscription": "Отменить подписку",
            "settings.user_id_required": "Введите User ID.",
            "settings.loaded": "Настройки загружены.",
            "settings.load_failed": "Не удалось загрузить настройки.",
            "settings.saved": "Настройки сохранены.",
            "settings.save_failed": "Не удалось сохранить настройки.",
            "settings.plans_loaded": "Планы загружены.",
            "settings.plans_load_failed": "Не удалось загрузить планы.",
            "settings.subscription_loaded": "Подписка загружена.",
            "settings.subscription_load_failed": "Не удалось загрузить подписку.",
            "settings.subscription_activated": "Подписка активирована.",
            "settings.subscription_activate_failed": "Не удалось активировать подписку.",
            "settings.subscription_canceled": "Подписка отменена.",
            "settings.subscription_cancel_failed": "Не удалось отменить подписку.",
            "settings.subscription_status_active": "активна",
            "settings.subscription_status_inactive": "неактивна",
            "settings.subscription_status_canceled": "отменена",
            "settings.logged_out": "Вы вышли из аккаунта.",
            "settings.log_out": "Выйти",
            "settings.help_title": "Справка",
            "settings.help_open": "Справочник HiAir",
            "settings.onboarding_reopen": "Показать onboarding снова",
            "settings.notifications_off_hint": "Уведомления выключены. Вы можете пропустить важные предупреждения о жаре и воздухе.",
            "settings.privacy_export": "Экспортировать мои данные",
            "settings.privacy_export_ready": "Секций данных",
            "settings.privacy_export_done": "Экспорт данных готов.",
            "settings.privacy_export_failed": "Не удалось экспортировать данные.",
            "settings.delete_account": "Удалить аккаунт",
            "settings.account_deleted": "Аккаунт удален.",
            "settings.account_delete_failed": "Не удалось удалить аккаунт.",
            "settings.user_id": "User ID",
            "settings.token": "Access token",
            "settings.window": "Окно",
            "settings.metric": "Метрика",
            "settings.metric.total": "Всего",
            "settings.metric.fallback": "Fallback",
            "settings.metric.guardrail": "Guardrail",
            "settings.metric.errors": "Ошибки (сумма)",
            "settings.metric.timeout": "Таймаут",
            "settings.metric.network": "Сеть",
            "settings.metric.server": "Сервер",
            "settings.mode": "Режим",
            "settings.mode.bars": "Столбцы",
            "settings.mode.line": "Линия",
            "settings.range": "Диапазон",
            "settings.axis": "Ось",
            "settings.request_status": "Статус запроса",
            "settings.request_loading": "Загрузка...",
            "settings.request_idle": "Ожидание",
            "settings.request_timeout": "Таймаут",
            "settings.last_updated": "Последнее обновление",
            "settings.ai_retry_now": "Повторить сейчас",
            "settings.ai_retry_later": "Повторить позже",
            "settings.ai_timeout_inline": "Превышено время ожидания AI запроса.",
            "settings.ai_network_inline": "Нет сети. Проверьте подключение и попробуйте снова.",
            "settings.ai_server_inline": "Сервер временно недоступен. Попробуйте позже.",
            "settings.ai_request_failed_inline": "Ошибка запроса AI наблюдаемости.",
            "settings.ai_top_prompt": "Топ версия промпта",
            "settings.ai_top_model": "Топ модель",
            "settings.ai_error_counts": "Ошибки",
            "settings.ai_error_type.timeout": "таймаут",
            "settings.ai_error_type.network": "сеть",
            "settings.ai_error_type.server": "сервер",
            "settings.ai_error_type.other": "прочее",
            "settings.ai_events": "AI события",
            "settings.ai_fallback": "fallback",
            "settings.ai_guardrail_blocks": "блокировки guardrail",
            "settings.ai_latest_hour": "Последний час",
            "settings.ai_blocks_short": "блоки",
            "settings.ai_no_trend": "Для выбранного периода нет точек тренда.",
            "settings.ai_loaded": "AI наблюдаемость загружена.",
            "settings.ai_failed": "Не удалось загрузить AI наблюдаемость.",
            "settings.ai_request_failed": "Запрос AI наблюдаемости завершился ошибкой.",
            "settings.load_ai_summary": "Загрузить AI сводку",
            "settings.loading_ai_metrics": "Загружаем AI метрики..."
            ,
            "common.close": "Закрыть",
            "guide.title": "Справочник HiAir",
            "guide.what_is_title": "Что такое HiAir",
            "guide.what_is_body": "HiAir — мобильный wellness-ассистент по жаре и качеству воздуха. Он показывает риск именно для вашего профиля.",
            "guide.problems_title": "Какие проблемы решает приложение",
            "guide.problems_body": "Помогает выбрать безопасное время для прогулки, спорта и проветривания, а также снизить риск при жаре и загрязнении воздуха.",
            "guide.for_whom_title": "Для кого HiAir полезен",
            "guide.for_whom_body": "Для взрослых, детей, пожилых людей и пользователей с астмой или аллергией, а также для тех, кто много времени проводит на улице.",
            "guide.read_dashboard_title": "Как читать главный экран",
            "guide.read_dashboard_body": "Сначала смотрите Risk Score, затем safe windows и рекомендации. Это три ключевых блока для решения «что делать сейчас».",
            "guide.risk_title": "Что означает Risk Score",
            "guide.risk_body": "Это общая оценка риска на основе жары, влажности и качества воздуха с учётом вашего профиля.",
            "guide.metrics_title": "Что такое AQI, PM2.5, озон, влажность и жара",
            "guide.metrics_body": "AQI показывает общий уровень загрязнения. PM2.5 — мелкие частицы. Озон у земли может ухудшать дыхание. Влажность и жара влияют на переносимость нагрузки.",
            "guide.hourly_title": "Как пользоваться прогнозом по часам",
            "guide.hourly_body": "Смотрите почасовой риск и планируйте активность на интервалы с более низким риском.",
            "guide.safe_windows_title": "Что такое безопасные окна",
            "guide.safe_windows_body": "Это интервалы, когда условия обычно лучше подходят для прогулки, спорта или проветривания.",
            "guide.symptoms_title": "Как пользоваться журналом симптомов",
            "guide.symptoms_body": "Отмечайте симптомы ежедневно. Это делает рекомендации более персональными и точными.",
            "guide.notifications_title": "Как настроить уведомления",
            "guide.notifications_body": "Включите уведомления, чтобы получать предупреждения о небезопасных условиях заранее.",
            "guide.high_risk_title": "Что делать при высоком риске",
            "guide.high_risk_body": "Снизьте нагрузку на улице, избегайте пиков жары, проветривайте в safe windows и следуйте рекомендациям приложения.",
            "guide.not_doctor_title": "Почему HiAir не заменяет врача",
            "guide.not_doctor_body": "HiAir помогает с повседневными решениями, но не ставит диагноз и не заменяет медицинскую помощь.",
            "guide.faq_title": "Частые вопросы",
            "guide.faq_body": "Если данные временно недоступны, попробуйте обновить экран или позже повторить запрос."
        ],
        "en": [
            "title.settings": "Settings",
            "tab.dashboard": "Dashboard",
            "tab.planner": "Planner",
            "tab.insights": "Insights",
            "insights.empty": "Log symptoms to unlock personal patterns.",
            "insights.unlock_more": "Log 5 more days to unlock patterns.",
            "insights.failed": "Failed to load insights.",
            "insights.count": "insights",
            "insights.loading": "Loading personal patterns...",
            "insights.retry": "Try again",
            "settings.briefing_setup_hint": "Sign in first to configure Morning Briefing.",
            "tab.symptoms": "Symptoms",
            "tab.settings": "Settings",
            "auth.title": "HiAir Account",
            "auth.email": "Email",
            "auth.password": "Password (min 12 chars, A/a/0-9/symbol)",
            "auth.sign_up": "Sign Up",
            "auth.signing_up": "Signing up...",
            "auth.log_in": "Log In",
            "auth.logging_in": "Logging in...",
            "auth.enter_email": "Enter email.",
            "auth.password_short": "Password must be at least 12 characters.",
            "auth.session_expired": "Session expired. Please sign in again.",
            "auth.ok": "Authenticated.",
            "auth.email_conflict": "An account with this email already exists.",
            "auth.backend_unreachable": "Cannot reach API. Ensure backend is running on 127.0.0.1:8000.",
            "auth.backend_unavailable": "Backend is temporarily unavailable. Check database connectivity.",
            "auth.fail": "Auth failed.",
            "onboarding.title": "HiAir Onboarding",
            "onboarding.persona": "Persona",
            "onboarding.sensitivity": "Sensitivity",
            "onboarding.latitude": "Latitude",
            "onboarding.longitude": "Longitude",
            "onboarding.profile_id": "Profile ID (optional)",
            "onboarding.continue": "Continue",
            "onboarding.next": "Next",
            "onboarding.back": "Back",
            "onboarding.start": "Start",
            "onboarding.step1.title": "HiAir is your heat and air-quality helper",
            "onboarding.step1.body": "HiAir helps you understand when heat and outdoor air can become unsafe specifically for you.",
            "onboarding.step2.title": "What HiAir helps you solve",
            "onboarding.problem.heat": "Heat and overheating risk",
            "onboarding.problem.pm25": "Poor air and PM2.5",
            "onboarding.problem.ozone": "Ozone, smoke, and pollution",
            "onboarding.problem.sensitive": "Kids, elderly, asthma and allergy",
            "onboarding.problem.outdoor": "Sports, walks, and outdoor work",
            "onboarding.step3.title": "Who are you using HiAir for?",
            "onboarding.for_self": "For myself",
            "onboarding.for_child": "For a child",
            "onboarding.for_elderly": "For an elderly person",
            "onboarding.for_asthma": "Asthma / breathing",
            "onboarding.for_allergy": "Allergy",
            "onboarding.for_runner": "Running / sports",
            "onboarding.for_worker": "Outdoor work",
            "onboarding.step4.title": "What to check daily",
            "onboarding.look.risk": "Risk Score shows your overall current risk",
            "onboarding.look.hourly": "Hourly forecast shows safer windows",
            "onboarding.look.recommendations": "Recommendations explain what to do",
            "onboarding.look.notifications": "Notifications warn you in advance",
            "onboarding.step5.title": "Why permissions matter",
            "onboarding.permissions.location.title": "Location",
            "onboarding.permissions.location.body": "Location helps calculate risk for your area.",
            "onboarding.permissions.notifications.title": "Notifications",
            "onboarding.permissions.notifications.body": "Notifications help warn you early about heat or poor air.",
            "onboarding.permissions.allow": "Allow",
            "onboarding.permissions.later": "Set up later",
            "onboarding.step6.title": "All set",
            "onboarding.step6.body": "Now open your home screen and check current risk, recommendations, and safe hours for today.",
            "onboarding.open_forecast": "Open my forecast",
            "dashboard.title": "Daily Air Intelligence",
            "common.city_updated": "Barcelona • Updated 2 min ago",
            "dashboard.subtitle": "Live risk, alerts and AI insights in one place.",
            "dashboard.greeting": "Good morning, Alex",
            "dashboard.improving": "Air quality is improving. Plan outdoors after 16:30.",
            "dashboard.current_risk": "Current risk",
            "dashboard.current_risk_title": "Current risk",
            "dashboard.badge_moderate": "MODERATE",
            "dashboard.reason_code": "Heat + ozone are driving today's risk.",
            "dashboard.tomorrow_hint": "Tomorrow risk may rise by 6 points due to a humidity spike.",
            "dashboard.location": "Barcelona",
            "dashboard.freshness_fresh": "fresh",
            "dashboard.freshness_stale": "refresh",
            "dashboard.profile_button": "Profile",
            "dashboard.no_safe_window": "No safe windows in the next hours.",
            "dashboard.error": "Unable to load data.",
            "dashboard.empty.no_profile.title": "Profile is not set",
            "dashboard.empty.no_profile.body": "Without profile HiAir cannot calculate personalized risk and safe windows.",
            "dashboard.empty.no_profile.cta": "Create profile automatically",
            "dashboard.empty.api_unavailable": "Data is temporarily unavailable. Check your connection and retry.",
            "dashboard.empty.location_missing": "Location is missing. Set your area in onboarding or settings.",
            "dashboard.recommended_actions": "Recommended actions",
            "dashboard.no_actions": "No actions available.",
            "dashboard.safe_window": "Safe window",
            "dashboard.safe_windows": "Safe windows",
            "dashboard.safe_windows_tooltip": "A part of the day when conditions are safer for walks, sports, or ventilation.",
            "dashboard.auto_updates": "Auto-updates by forecast",
            "dashboard.do_now": "Do this now",
            "dashboard.recommendations_tooltip": "Personalized advice based on your current risk and profile.",
            "dashboard.action_1": "Avoid direct sun from 10:00 to 15:00",
            "dashboard.action_2": "Hydrate every 45 minutes",
            "dashboard.action_3": "Best outdoor window 16:30 - 19:00",
            "dashboard.recompute": "Recompute risk now",
            "dashboard.log_symptoms": "Log symptoms now",
            "dashboard.loading": "Loading...",
            "dashboard.get_started.title": "How to start",
            "dashboard.get_started.hide": "Hide",
            "dashboard.get_started.item.risk": "Check current risk level",
            "dashboard.get_started.item.hourly": "Open hourly forecast",
            "dashboard.get_started.item.recommendations": "Read recommendations",
            "dashboard.get_started.item.profile": "Set up your profile",
            "dashboard.get_started.item.notifications": "Turn on notifications",
            "dashboard.air_metrics": "Air metrics",
            "dashboard.metric.aqi": "AQI",
            "dashboard.metric.pm25": "PM2.5",
            "dashboard.metric.ozone": "Ozone",
            "dashboard.metric.heat_index": "Heat Index",
            "dashboard.metric.humidity": "Humidity",
            "dashboard.tooltip.risk_score": "Overall risk estimate for you based on heat, humidity, and air quality.",
            "dashboard.tooltip.aqi": "Air Quality Index. The higher the number, the worse the air.",
            "dashboard.tooltip.pm25": "Fine pollution particles that can irritate your lungs.",
            "dashboard.tooltip.ozone": "Ground-level ozone can worsen breathing, especially on hot days.",
            "dashboard.tooltip.heat_index": "How hot it feels when humidity is included.",
            "planner.title": "Daily Planner",
            "planner.subtitle": "Complete recommendations based on your profile and air trends.",
            "planner.safe_windows": "Safe windows",
            "planner.ventilation_windows": "Ventilation windows",
            "planner.hourly_risk": "Hourly risk",
            "planner.hourly": "Hour-by-hour",
            "planner.refresh": "Refresh planner",
            "planner.apply": "Apply this plan",
            "planner.loading": "Loading...",
            "planner.profile_required": "Profile ID is required.",
            "planner.fetch": "Load daily plan to see the key interval.",
            "planner.failed": "Failed to load planner.",
            "planner.empty.no_profile.title": "Profile is not set yet",
            "planner.empty.no_profile.body": "HiAir needs your profile to calculate personalized safe windows.",
            "planner.empty.no_profile.cta": "Create profile automatically",
            "planner.empty.unavailable.title": "Forecast is temporarily unavailable",
            "planner.empty.unavailable.body": "Check your connection and try again in a minute.",
            "symptoms.title": "Symptoms Log",
            "symptoms.subtitle": "Track how you feel for better personalized guidance.",
            "symptoms.streak": "Streak: 4 days in a row",
            "symptoms.profile_id": "Profile ID",
            "symptoms.cough": "Cough",
            "symptoms.wheeze": "Wheeze",
            "symptoms.headache": "Headache",
            "symptoms.fatigue": "Fatigue",
            "symptoms.sleep_quality": "Sleep quality",
            "symptoms.quick_intensity": "Quick intensity",
            "symptoms.quick_breath": "Quick: Breath",
            "symptoms.quick_headache": "Quick: Headache",
            "symptoms.save": "Save Symptoms",
            "symptoms.submit": "Submit symptoms",
            "symptoms.saving": "Saving...",
            "symptoms.saved_at": "Saved at",
            "symptoms.save_failed": "Failed to save symptoms.",
            "symptoms.quick_saved": "Quick symptom saved.",
            "symptoms.quick_failed": "Failed to save quick symptom.",
            "symptoms.empty.title": "Symptoms log is empty",
            "symptoms.empty.body": "Add your first symptom to make HiAir recommendations more precise.",
            "settings.ai_observability": "AI Observability",
            "settings.subtitle": "Manage notifications, subscriptions and AI observability.",
            "settings.notifications": "Notifications",
            "settings.push": "Enable push alerts",
            "settings.morning_briefing": "Morning Briefing",
            "settings.morning_briefing_time": "Briefing time (HH:MM)",
            "settings.morning_briefing_hint": "Personal summary delivered every morning.",
            "settings.profile_alerting": "Profile-based alerting",
            "settings.alert_threshold": "Alert threshold",
            "settings.threshold_medium": "Medium",
            "settings.threshold_high": "High",
            "settings.threshold_very_high": "Very high",
            "settings.quiet_start": "Quiet start",
            "settings.quiet_end": "Quiet end",
            "settings.profile_defaults": "Profile defaults",
            "settings.persona": "Persona",
            "settings.persona_adult": "Adult",
            "settings.persona_child": "Child",
            "settings.persona_elderly": "Elderly",
            "settings.persona_asthma": "Asthma",
            "settings.persona_allergy": "Allergy",
            "settings.persona_runner": "Runner",
            "settings.persona_worker": "Outdoor worker",
            "settings.language": "Language",
            "settings.language_ru": "Russian",
            "settings.language_en": "English",
            "settings.window_24h": "24h",
            "settings.window_72h": "72h",
            "settings.sync": "Sync",
            "settings.loading": "Loading...",
            "settings.saving": "Saving...",
            "settings.subscription": "Subscription",
            "settings.security_privacy": "Security & Privacy",
            "settings.plan": "Plan",
            "settings.status": "Status",
            "settings.sync_now": "Save settings & sync",
            "settings.advanced_controls": "Advanced chart controls",
            "settings.load": "Load settings",
            "settings.save": "Save settings",
            "settings.load_plans": "Load plans",
            "settings.load_subscription": "Load subscription",
            "settings.activate_subscription": "Activate subscription",
            "settings.cancel_subscription": "Cancel subscription",
            "settings.user_id_required": "Enter user ID.",
            "settings.loaded": "Settings loaded.",
            "settings.load_failed": "Failed to load settings.",
            "settings.saved": "Settings saved.",
            "settings.save_failed": "Failed to save settings.",
            "settings.plans_loaded": "Plans loaded.",
            "settings.plans_load_failed": "Failed to load plans.",
            "settings.subscription_loaded": "Subscription loaded.",
            "settings.subscription_load_failed": "Failed to load subscription.",
            "settings.subscription_activated": "Subscription activated.",
            "settings.subscription_activate_failed": "Failed to activate subscription.",
            "settings.subscription_canceled": "Subscription canceled.",
            "settings.subscription_cancel_failed": "Failed to cancel subscription.",
            "settings.subscription_status_active": "active",
            "settings.subscription_status_inactive": "inactive",
            "settings.subscription_status_canceled": "canceled",
            "settings.logged_out": "Logged out.",
            "settings.log_out": "Log out",
            "settings.help_title": "Help",
            "settings.help_open": "HiAir Guide",
            "settings.onboarding_reopen": "Open onboarding again",
            "settings.notifications_off_hint": "Notifications are off. You may miss important heat and air alerts.",
            "settings.privacy_export": "Export my data",
            "settings.privacy_export_ready": "Data sections",
            "settings.privacy_export_done": "Data export is ready.",
            "settings.privacy_export_failed": "Failed to export data.",
            "settings.delete_account": "Delete account",
            "settings.account_deleted": "Account deleted.",
            "settings.account_delete_failed": "Failed to delete account.",
            "settings.user_id": "User ID",
            "settings.token": "Access token",
            "settings.window": "Window",
            "settings.metric": "Metric",
            "settings.metric.total": "Total",
            "settings.metric.fallback": "Fallback",
            "settings.metric.guardrail": "Guardrail",
            "settings.metric.errors": "Errors (sum)",
            "settings.metric.timeout": "Timeout",
            "settings.metric.network": "Network",
            "settings.metric.server": "Server",
            "settings.mode": "Mode",
            "settings.mode.bars": "Bars",
            "settings.mode.line": "Line",
            "settings.range": "Range",
            "settings.axis": "Axis",
            "settings.request_status": "Request status",
            "settings.request_loading": "Loading...",
            "settings.request_idle": "Idle",
            "settings.request_timeout": "Timeout",
            "settings.last_updated": "Last updated",
            "settings.ai_retry_now": "Retry now",
            "settings.ai_retry_later": "Try later",
            "settings.ai_timeout_inline": "AI observability request timed out.",
            "settings.ai_network_inline": "Network unavailable. Check your connection and retry.",
            "settings.ai_server_inline": "Server is temporarily unavailable. Please try later.",
            "settings.ai_request_failed_inline": "AI observability request failed.",
            "settings.ai_top_prompt": "Top prompt version",
            "settings.ai_top_model": "Top model",
            "settings.ai_error_counts": "Errors",
            "settings.ai_error_type.timeout": "timeout",
            "settings.ai_error_type.network": "network",
            "settings.ai_error_type.server": "server",
            "settings.ai_error_type.other": "other",
            "settings.ai_events": "AI events",
            "settings.ai_fallback": "fallback",
            "settings.ai_guardrail_blocks": "guardrail blocks",
            "settings.ai_latest_hour": "Latest hour",
            "settings.ai_blocks_short": "blocks",
            "settings.ai_no_trend": "No trend points for selected period.",
            "settings.ai_loaded": "AI observability loaded.",
            "settings.ai_failed": "Failed to load AI observability.",
            "settings.ai_request_failed": "AI observability request failed.",
            "settings.load_ai_summary": "Load AI Summary",
            "settings.loading_ai_metrics": "Loading AI metrics...",
            "common.close": "Close",
            "guide.title": "HiAir Guide",
            "guide.what_is_title": "What is HiAir",
            "guide.what_is_body": "HiAir is a mobile wellness assistant for heat and air quality. It shows risk tailored to your profile.",
            "guide.problems_title": "What problems it solves",
            "guide.problems_body": "It helps you choose safer times for walks, sports, and home ventilation, and reduce risk during heat and polluted air.",
            "guide.for_whom_title": "Who benefits from HiAir",
            "guide.for_whom_body": "Adults, children, elderly users, and people with asthma or allergy, as well as users who spend time outdoors.",
            "guide.read_dashboard_title": "How to read the home screen",
            "guide.read_dashboard_body": "Start with Risk Score, then review safe windows and recommendations. These are the three key daily blocks.",
            "guide.risk_title": "What Risk Score means",
            "guide.risk_body": "It is your overall risk estimate based on heat, humidity, and air quality, adjusted for your profile.",
            "guide.metrics_title": "What AQI, PM2.5, ozone, humidity, and heat mean",
            "guide.metrics_body": "AQI shows total pollution burden. PM2.5 are tiny particles. Ground-level ozone can irritate breathing. Humidity and heat affect comfort and stress.",
            "guide.hourly_title": "How to use hourly forecast",
            "guide.hourly_body": "Check hourly risk and plan activity for periods with lower risk.",
            "guide.safe_windows_title": "What safe windows are",
            "guide.safe_windows_body": "Time intervals when conditions are usually safer for walks, sports, or ventilation.",
            "guide.symptoms_title": "How to use symptom log",
            "guide.symptoms_body": "Track symptoms daily to make recommendations more personalized and accurate.",
            "guide.notifications_title": "How to configure notifications",
            "guide.notifications_body": "Turn on notifications to get warnings before unsafe conditions.",
            "guide.high_risk_title": "What to do at high risk",
            "guide.high_risk_body": "Reduce outdoor intensity, avoid peak heat, ventilate during safe windows, and follow recommendations.",
            "guide.not_doctor_title": "Why HiAir is not a doctor replacement",
            "guide.not_doctor_body": "HiAir supports daily decisions but does not provide diagnosis or replace medical care.",
            "guide.faq_title": "FAQ",
            "guide.faq_body": "If data is temporarily unavailable, refresh the screen or try again later."
        ]
    ]
}

extension AppSession {
    func l(_ key: String) -> String {
        HiAirL10n.t(key, lang: preferredLanguage)
    }
}
