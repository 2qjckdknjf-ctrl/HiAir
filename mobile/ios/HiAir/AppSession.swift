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
        static let email = "session.email"
        static let profileId = "session.profileId"
        static let persona = "session.persona"
        static let sensitivity = "session.sensitivity"
        static let preferredLanguage = "session.preferredLanguage"
        static let latitude = "session.latitude"
        static let longitude = "session.longitude"
    }

    @Published var onboardingCompleted = false { didSet { persist() } }
    @Published var userId = "" { didSet { persist() } }
    @Published var email = "" { didSet { persist() } }
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
    @Published var showPaywall = false
    @Published var isPremium = false
    @Published var selectedTab = 0
    private let apiClient = APIClient.live()
    private let keychain = KeychainStore(service: "com.hiair.app.session")
    private let supabaseAuth = SupabaseAuthService.shared
    private var authObserver: NSObjectProtocol?

    init() {
        let defaults = UserDefaults.standard
        onboardingCompleted = defaults.object(forKey: Keys.onboardingCompleted) as? Bool ?? false
        userId = keychain.getString(forKey: Keys.userId) ?? defaults.string(forKey: Keys.userId) ?? ""
        email = keychain.getString(forKey: Keys.email) ?? defaults.string(forKey: Keys.email) ?? ""
        accessToken = keychain.getString(forKey: Keys.accessToken) ?? defaults.string(forKey: Keys.accessToken) ?? ""
        refreshToken = keychain.getString(forKey: Keys.refreshToken) ?? defaults.string(forKey: Keys.refreshToken) ?? ""
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
        authObserver = NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let session = note.object as? SupabaseAuthSession
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let session else {
                    self.logout()
                    return
                }
                self.userId = session.userId
                self.email = session.email
                self.accessToken = session.accessToken
                self.refreshToken = session.refreshToken
                self.authNotice = ""
            }
        }
        NotificationCenter.default.addObserver(
            forName: SupabaseAuthService.sessionOAuthFailed,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let message = note.object as? String ?? ""
            Task { @MainActor [weak self] in
                guard let self, !message.isEmpty else { return }
                self.authNotice = message
            }
        }
        Task { @MainActor [weak self] in
            await self?.restoreSupabaseSession()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        if let authObserver {
            NotificationCenter.default.removeObserver(authObserver)
        }
    }

    func logout() {
        Task {
            await supabaseAuth.signOut()
        }
        userId = ""
        email = ""
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

    /// Apply Supabase tokens in one shot so `persist()` does not clear API auth mid-update.
    func installAuthSession(_ auth: SupabaseAuthSession) {
        userId = auth.userId
        email = auth.email
        accessToken = auth.accessToken
        refreshToken = auth.refreshToken
        authNotice = ""
    }

    func applyEntitlement(_ entitlement: UserEntitlementResponse?) {
        isPremium = entitlement?.isPremium ?? false
    }

    func refreshEntitlement() async {
        guard !userId.isEmpty, !accessToken.isEmpty else {
            isPremium = false
            return
        }
        do {
            let status = try await apiClient.fetchMySubscription(userId: userId, accessToken: accessToken)
            applyEntitlement(status.entitlement)
        } catch {
            isPremium = false
        }
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
        defaults.set(profileId, forKey: Keys.profileId)
        defaults.set(persona, forKey: Keys.persona)
        defaults.set(sensitivity, forKey: Keys.sensitivity)
        defaults.set(preferredLanguage, forKey: Keys.preferredLanguage)
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
        defaults.set(Array(checklistCompletedItems).sorted(), forKey: Keys.checklistCompletedItems)
        defaults.set(checklistHidden, forKey: Keys.checklistHidden)
        if userId.isEmpty {
            keychain.deleteValue(forKey: Keys.userId)
        } else {
            keychain.setString(userId, forKey: Keys.userId)
        }
        if email.isEmpty {
            keychain.deleteValue(forKey: Keys.email)
        } else {
            keychain.setString(email, forKey: Keys.email)
        }
        if accessToken.isEmpty {
            keychain.deleteValue(forKey: Keys.accessToken)
        } else {
            keychain.setString(accessToken, forKey: Keys.accessToken)
        }
        if refreshToken.isEmpty {
            keychain.deleteValue(forKey: Keys.refreshToken)
        } else {
            keychain.setString(refreshToken, forKey: Keys.refreshToken)
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

    private func restoreSupabaseSession() async {
        do {
            guard let session = try await supabaseAuth.restoreSessionIfNeeded() else {
                return
            }
            userId = session.userId
            email = session.email
            accessToken = session.accessToken
            refreshToken = session.refreshToken
            authNotice = ""
        } catch {
            // Keep local session as source of truth when restore fails.
        }
    }
}

enum HiAirL10n {
    static func t(_ key: String, lang: String) -> String {
        let language = normalizedLanguageCode(lang)
        return strings[language]?[key] ?? strings["ru"]?[key] ?? key
    }

    private static func normalizedLanguageCode(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("fr") { return "fr" }
        if lower.hasPrefix("it") { return "it" }
        if lower.hasPrefix("es") { return "es" }
        if lower.hasPrefix("en") { return "en" }
        return "ru"
    }

    private static let strings: [String: [String: String]] = {
        var all = baseStrings
        let english = baseStrings["en"] ?? [:]
        for code in ["es", "it", "fr"] {
            all[code] = english.merging(localizedOverrides[code] ?? [:]) { _, new in new }
        }
        return all
    }()

    private static let baseStrings: [String: [String: String]] = [
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
            "settings.briefing_setup_hint": "Сначала войдите в аккаунт, чтобы настроить «Утренний брифинг».",
            "tab.symptoms": "Симптомы",
            "tab.settings": "Настройки",
            "auth.title": "Аккаунт HiAir",
            "auth.subtitle": "Breathe better. Live better.",
            "brand.tagline": "Breathe better. Live better.",
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
            "auth.backend_unreachable": "Нет подключения к серверу. Проверьте интернет и повторите.",
            "auth.backend_unavailable": "Backend временно недоступен. Проверьте подключение к базе данных.",
            "auth.confirm_email": "Мы отправили письмо на %@. Откройте ссылку в письме, затем нажмите «Войти» с тем же паролем.",
            "auth.confirm_email_short": "Подтвердите email, затем войдите.",
            "auth.oauth_continue": "Завершите вход в браузере, затем вернитесь в HiAir.",
            "auth.cancelled": "Вход отменён.",
            "auth.fail": "Ошибка авторизации.",
            "auth.server_error": "Ошибка сервера (%d). Повторите позже.",
            "auth.oauth_not_configured": "Вход через %@ пока не настроен на сервере. Используйте email и пароль или обновите приложение позже.",
            "auth.rate_limited": "Слишком много попыток. Подождите 15 минут и повторите вход.",
            "auth.bridge_unreachable": "Сервер авторизации временно недоступен. Повторите через минуту.",
            "auth.working": "Подключаемся к серверу…",
            "auth.bad_response": "Некорректный ответ сервера. Обновите приложение или повторите позже.",
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
            "dashboard.weather_title": "Солнечно, 26C",
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
            "dashboard.mood_prefix": "Состояние",
            "dashboard.mood.calm": "Спокойно",
            "dashboard.mood.aware": "Внимательно",
            "dashboard.mood.cautious": "Осторожно",
            "dashboard.mood.protective": "Защита",
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
            "settings.language_es": "Español",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Français",
            "settings.window_24h": "24ч",
            "settings.window_72h": "72ч",
            "settings.sync": "Синхронизация",
            "settings.loading": "Загрузка...",
            "settings.saving": "Сохраняем...",
            "settings.subscription": "Подписка",
            "settings.upgrade_premium": "Перейти на Premium",
            "paywall.nav_title": "Premium",
            "paywall.title": "HiAir Premium",
            "paywall.subtitle": "Семейные профили, расширенный прогноз и персональные инсайты.",
            "paywall.benefit.profiles": "До 6 семейных профилей",
            "paywall.benefit.forecast": "Почасовой прогноз и безопасные окна",
            "paywall.benefit.alerts": "Персональные брифинги и алерты",
            "paywall.benefit.export": "Экспорт данных",
            "paywall.benefit.insights": "Расширенные инсайты",
            "paywall.loading": "Загрузка планов…",
            "paywall.products_unavailable": "Планы недоступны в App Store.",
            "paywall.retry": "Повторить",
            "paywall.restore": "Восстановить покупки",
            "paywall.disclaimer": "HiAir — wellness-напоминания, не медицинский совет.",
            "paywall.terms": "Условия",
            "paywall.privacy": "Конфиденциальность",
            "paywall.success": "Premium активирован.",
            "paywall.restore_success": "Покупки восстановлены.",
            "common.close": "Закрыть",
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
            "settings.ai_guide_open": "ИИ-гид",
            "settings.onboarding_reopen": "Показать онбординг снова",
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
            "settings.loading_ai_metrics": "Загружаем AI метрики...",
            "guide.title": "Справочник HiAir",
            "guide.what_is_title": "Что такое HiAir",
            "guide.what_is_body": "HiAir — мобильный ассистент по жаре и качеству воздуха. Он показывает риск именно для вашего профиля.",
            "guide.problems_title": "Какие проблемы решает приложение",
            "guide.problems_body": "Помогает выбрать безопасное время для прогулки, спорта и проветривания, а также снизить риск при жаре и загрязнении воздуха.",
            "guide.for_whom_title": "Для кого HiAir полезен",
            "guide.for_whom_body": "Для взрослых, детей, пожилых людей и пользователей с астмой или аллергией, а также для тех, кто много времени проводит на улице.",
            "guide.read_dashboard_title": "Как читать главный экран",
            "guide.read_dashboard_body": "Сначала смотрите Risk Score, затем безопасные окна и рекомендации. Это три ключевых блока для решения «что делать сейчас».",
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
            "guide.high_risk_body": "Снизьте нагрузку на улице, избегайте пиков жары, проветривайте в безопасные окна и следуйте рекомендациям приложения.",
            "guide.not_doctor_title": "Почему HiAir не заменяет врача",
            "guide.not_doctor_body": "HiAir помогает с повседневными решениями, но не ставит диагноз и не заменяет медицинскую помощь.",
            "guide.faq_title": "Частые вопросы",
            "guide.faq_body": "Если данные временно недоступны, попробуйте обновить экран или позже повторить запрос.",
            "ai_guide.title": "ИИ-гид HiAir",
            "ai_guide.placeholder": "Спросите, как пользоваться приложением...",
            "ai_guide.send": "Спросить",
            "ai_guide.clear": "Новый диалог",
            "ai_guide.greeting": "Привет! Я ИИ-гид HiAir. Задайте вопрос, и я дам короткий пошаговый ответ.",
            "ai_guide.subtitle": "Подскажу шаги и сразу проведу к нужному экрану",
            "ai_guide.language_hint": "Отвечаю на языке приложения:",
            "ai_guide.user_label": "Вы",
            "ai_guide.assistant_label": "HiAir Гид",
            "ai_guide.followup": "Если нужно, задайте уточняющий вопрос — разберем подробнее.",
            "ai_guide.action.open_dashboard": "Открыть Главную",
            "ai_guide.action.open_planner": "Открыть План",
            "ai_guide.action.open_insights": "Открыть Инсайты",
            "ai_guide.action.open_symptoms": "Открыть Симптомы",
            "ai_guide.action.open_notifications": "Открыть Настройки",
            "ai_guide.action.open_account": "Открыть Аккаунт",
            "ai_guide.action.open_onboarding": "Запустить онбординг",
            "ai_guide.suggestion.onboarding": "Как начать пользоваться приложением?",
            "ai_guide.suggestion.risk": "Как интерпретировать Risk, AQI и PM2.5?",
            "ai_guide.suggestion.safe_windows": "Как использовать безопасные окна?",
            "ai_guide.suggestion.notifications": "Как включить уведомления?",
            "ai_guide.suggestion.symptoms": "Как вести журнал симптомов?",
            "ai_guide.suggestion.account": "Как управлять аккаунтом и данными?",
            "ai_guide.intent.onboarding.title": "Как начать работу с HiAir:",
            "ai_guide.intent.onboarding.step1": "Войдите или зарегистрируйтесь на экране аккаунта.",
            "ai_guide.intent.onboarding.step2": "Пройдите онбординг и выберите, для кого используете HiAir.",
            "ai_guide.intent.onboarding.step3": "На главном экране посмотрите Risk Score и чек-лист «С чего начать».",
            "ai_guide.intent.onboarding.step4": "Откройте вкладку «План» и проверьте безопасные окна на сегодня.",
            "ai_guide.intent.risk.title": "Как читать показатели риска:",
            "ai_guide.intent.risk.step1": "Сначала смотрите Risk Score — это общий риск именно для вашего профиля.",
            "ai_guide.intent.risk.step2": "AQI показывает общее загрязнение воздуха: чем выше число, тем хуже условия.",
            "ai_guide.intent.risk.step3": "PM2.5 и озон показывают факторы, которые чаще всего ухудшают дыхание.",
            "ai_guide.intent.risk.step4": "При высоком риске ориентируйтесь на рекомендации и безопасные окна.",
            "ai_guide.intent.planner.title": "Как использовать прогноз и безопасные окна:",
            "ai_guide.intent.planner.step1": "Откройте вкладку «План дня».",
            "ai_guide.intent.planner.step2": "Посмотрите почасовой риск и найдите интервалы с более низким риском.",
            "ai_guide.intent.planner.step3": "Перенесите прогулку, спорт или проветривание на безопасные окна.",
            "ai_guide.intent.planner.step4": "Если условий нет, сократите активность на улице и проверьте обновление позже.",
            "ai_guide.intent.notifications.title": "Как настроить уведомления:",
            "ai_guide.intent.notifications.step1": "Откройте «Настройки -> Уведомления».",
            "ai_guide.intent.notifications.step2": "Включите push-уведомления и при необходимости «Утренний брифинг».",
            "ai_guide.intent.notifications.step3": "Выставьте порог алертов и тихие часы под ваш режим дня.",
            "ai_guide.intent.notifications.step4": "Сохраните настройки и убедитесь, что пункт чек-листа отмечен.",
            "ai_guide.intent.symptoms.title": "Как вести журнал симптомов и получать инсайты:",
            "ai_guide.intent.symptoms.step1": "Откройте вкладку «Симптомы» и добавляйте самочувствие регулярно.",
            "ai_guide.intent.symptoms.step2": "Используйте быстрые кнопки, если нет времени на полный ввод.",
            "ai_guide.intent.symptoms.step3": "После накопления данных откройте «Инсайты» для персональных паттернов.",
            "ai_guide.intent.symptoms.step4": "Сравнивайте инсайты с погодой и качеством воздуха при планировании дня.",
            "ai_guide.intent.account.title": "Как управлять аккаунтом, профилем и приватностью:",
            "ai_guide.intent.account.step1": "В разделе «Настройки» проверьте User ID, язык и профиль по умолчанию.",
            "ai_guide.intent.account.step2": "Для бэкапа используйте «Экспортировать мои данные».",
            "ai_guide.intent.account.step3": "При необходимости можно выйти из аккаунта или удалить его.",
            "ai_guide.intent.account.step4": "После изменений синхронизируйте настройки кнопкой внизу экрана.",
            "ai_guide.intent.fallback.title": "Универсальный план по любому вопросу:",
            "ai_guide.intent.fallback.step1": "Опишите цель: что хотите сделать в приложении.",
            "ai_guide.intent.fallback.step2": "Укажите, на каком экране вы сейчас находитесь.",
            "ai_guide.intent.fallback.step3": "Я подскажу точный путь по кнопкам и экранам шаг за шагом.",
            "ai_guide.intent.fallback.step4": "Если что-то не работает, пришлите текст ошибки — подскажу, как исправить.",
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
            "auth.subtitle": "Breathe better. Live better.",
            "brand.tagline": "Breathe better. Live better.",
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
            "auth.backend_unreachable": "Cannot reach the server. Check your internet connection and try again.",
            "auth.backend_unavailable": "Backend is temporarily unavailable. Check database connectivity.",
            "auth.confirm_email": "We sent a confirmation link to %@. Open it, then tap Log in with the same password.",
            "auth.confirm_email_short": "Confirm your email, then log in.",
            "auth.oauth_continue": "Finish sign-in in the browser, then return to HiAir.",
            "auth.cancelled": "Sign-in cancelled.",
            "auth.fail": "Auth failed.",
            "auth.server_error": "Server error (%d). Try again later.",
            "auth.oauth_not_configured": "Sign in with %@ is not configured yet. Use email and password instead.",
            "auth.rate_limited": "Too many attempts. Wait 15 minutes and try again.",
            "auth.bridge_unreachable": "Auth server is temporarily unavailable. Try again in a minute.",
            "auth.working": "Connecting to the server…",
            "auth.bad_response": "Unexpected server response. Update the app or try again later.",
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
            "dashboard.weather_title": "Sunny, 26C",
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
            "dashboard.mood_prefix": "Mood",
            "dashboard.mood.calm": "Calm",
            "dashboard.mood.aware": "Aware",
            "dashboard.mood.cautious": "Cautious",
            "dashboard.mood.protective": "Protective",
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
            "settings.language_es": "Spanish",
            "settings.language_it": "Italian",
            "settings.language_fr": "French",
            "settings.window_24h": "24h",
            "settings.window_72h": "72h",
            "settings.sync": "Sync",
            "settings.loading": "Loading...",
            "settings.saving": "Saving...",
            "settings.subscription": "Subscription",
            "settings.upgrade_premium": "Upgrade to Premium",
            "paywall.nav_title": "Premium",
            "paywall.title": "HiAir Premium",
            "paywall.subtitle": "Family profiles, extended forecast, and advanced insights.",
            "paywall.benefit.profiles": "Up to 6 family profiles",
            "paywall.benefit.forecast": "Hourly forecast and safe windows",
            "paywall.benefit.alerts": "Custom briefings and alerts",
            "paywall.benefit.export": "Data export",
            "paywall.benefit.insights": "Advanced personal insights",
            "paywall.loading": "Loading plans…",
            "paywall.products_unavailable": "Plans are unavailable from the App Store.",
            "paywall.retry": "Retry",
            "paywall.restore": "Restore purchases",
            "paywall.disclaimer": "HiAir provides wellness guidance, not medical advice.",
            "paywall.terms": "Terms",
            "paywall.privacy": "Privacy",
            "paywall.success": "Premium activated.",
            "paywall.restore_success": "Purchases restored.",
            "common.close": "Close",
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
            "settings.ai_guide_open": "AI Assistant",
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
            "guide.faq_body": "If data is temporarily unavailable, refresh the screen or try again later.",
            "ai_guide.title": "HiAir AI Assistant",
            "ai_guide.placeholder": "Ask how to use the app...",
            "ai_guide.send": "Ask",
            "ai_guide.clear": "New chat",
            "ai_guide.greeting": "Hi! I am your HiAir AI Assistant. Ask a question and I will reply with clear step-by-step actions.",
            "ai_guide.subtitle": "I can guide you and open the right screen",
            "ai_guide.language_hint": "Answering in app language:",
            "ai_guide.user_label": "You",
            "ai_guide.assistant_label": "HiAir Assistant",
            "ai_guide.followup": "Need more detail? Ask a follow-up and I will break it down further.",
            "ai_guide.action.open_dashboard": "Open Dashboard",
            "ai_guide.action.open_planner": "Open Planner",
            "ai_guide.action.open_insights": "Open Insights",
            "ai_guide.action.open_symptoms": "Open Symptoms",
            "ai_guide.action.open_notifications": "Open Settings",
            "ai_guide.action.open_account": "Open Account",
            "ai_guide.action.open_onboarding": "Start onboarding",
            "ai_guide.suggestion.onboarding": "How do I start using the app?",
            "ai_guide.suggestion.risk": "How do I interpret Risk, AQI, and PM2.5?",
            "ai_guide.suggestion.safe_windows": "How do I use safe windows?",
            "ai_guide.suggestion.notifications": "How do I enable notifications?",
            "ai_guide.suggestion.symptoms": "How do I log symptoms?",
            "ai_guide.suggestion.account": "How do I manage my account and data?",
            "ai_guide.intent.onboarding.title": "How to start with HiAir:",
            "ai_guide.intent.onboarding.step1": "Sign in or register on the account screen.",
            "ai_guide.intent.onboarding.step2": "Complete onboarding and select who you use HiAir for.",
            "ai_guide.intent.onboarding.step3": "On Dashboard, review Risk Score and the “Get Started” checklist.",
            "ai_guide.intent.onboarding.step4": "Open Planner and review safe windows for today.",
            "ai_guide.intent.risk.title": "How to read risk metrics:",
            "ai_guide.intent.risk.step1": "Start with Risk Score - it reflects your personalized overall risk level.",
            "ai_guide.intent.risk.step2": "AQI shows total air pollution burden: higher value means worse air.",
            "ai_guide.intent.risk.step3": "PM2.5 and ozone show factors that often worsen breathing comfort.",
            "ai_guide.intent.risk.step4": "At high risk, follow recommendations and schedule around safe windows.",
            "ai_guide.intent.planner.title": "How to use the forecast and safe windows:",
            "ai_guide.intent.planner.step1": "Open the Planner tab.",
            "ai_guide.intent.planner.step2": "Check hourly risk and identify lower-risk time intervals.",
            "ai_guide.intent.planner.step3": "Move walks, sports, or ventilation to safe windows.",
            "ai_guide.intent.planner.step4": "If no safe interval exists, reduce outdoor load and re-check later.",
            "ai_guide.intent.notifications.title": "How to set up notifications:",
            "ai_guide.intent.notifications.step1": "Open Settings > Notifications.",
            "ai_guide.intent.notifications.step2": "Enable push notifications and, if needed, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Set alert threshold and quiet hours for your daily routine.",
            "ai_guide.intent.notifications.step4": "Save settings and confirm the checklist item is marked as done.",
            "ai_guide.intent.symptoms.title": "How to log symptoms and use insights:",
            "ai_guide.intent.symptoms.step1": "Open Symptoms tab and track your status regularly.",
            "ai_guide.intent.symptoms.step2": "Use quick buttons when you need fast logging.",
            "ai_guide.intent.symptoms.step3": "After accumulating data, open Insights for personal patterns.",
            "ai_guide.intent.symptoms.step4": "Use those patterns with weather and air data to plan your day.",
            "ai_guide.intent.account.title": "How to manage account, profile, and privacy:",
            "ai_guide.intent.account.step1": "In Settings, review User ID, language, and default profile.",
            "ai_guide.intent.account.step2": "Use “Export my data” when you need a privacy copy.",
            "ai_guide.intent.account.step3": "You can log out or delete your account when needed.",
            "ai_guide.intent.account.step4": "After changes, sync settings using the button at the bottom.",
            "ai_guide.intent.fallback.title": "Universal plan for any question:",
            "ai_guide.intent.fallback.step1": "Describe your goal in one sentence.",
            "ai_guide.intent.fallback.step2": "Tell me which screen you are currently on.",
            "ai_guide.intent.fallback.step3": "I will provide the exact button-by-button path.",
            "ai_guide.intent.fallback.step4": "If something fails, send the error text and I will provide a fix plan.",
        ]
    ]

    private static let localizedOverrides: [String: [String: String]] = [
        "es": [
            "tab.dashboard": "Inicio",
            "tab.planner": "Plan",
            "tab.insights": "Insights",
            "tab.symptoms": "Síntomas",
            "tab.settings": "Ajustes",
            "title.settings": "Ajustes",
            "auth.title": "Cuenta HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Correo",
            "auth.password": "Contraseña (mín. 12 caracteres, A/a/0-9/símbolo)",
            "auth.sign_up": "Registrarse",
            "auth.log_in": "Iniciar sesión",
            "auth.enter_email": "Introduce el correo.",
            "auth.password_short": "La contraseña debe tener al menos 12 caracteres.",
            "onboarding.start": "Comenzar",
            "onboarding.next": "Siguiente",
            "onboarding.back": "Atrás",
            "onboarding.step1.title": "HiAir es tu asistente de calor y calidad del aire",
            "onboarding.step1.body": "HiAir te ayuda a entender cuándo el calor y el aire exterior pueden ser inseguros para ti.",
            "onboarding.step2.title": "Qué problemas resuelve HiAir",
            "onboarding.step3.title": "¿Para quién usas HiAir?",
            "onboarding.step4.title": "Qué revisar cada día",
            "onboarding.step5.title": "Por qué importan los permisos",
            "onboarding.step6.title": "Todo listo",
            "onboarding.open_forecast": "Abrir mi pronóstico",
            "dashboard.title": "Inteligencia diaria del aire",
            "dashboard.get_started.title": "Cómo empezar",
            "dashboard.get_started.hide": "Ocultar",
            "dashboard.get_started.item.risk": "Revisa el nivel de riesgo actual",
            "dashboard.get_started.item.hourly": "Abre el pronóstico por hora",
            "dashboard.get_started.item.recommendations": "Lee las recomendaciones",
            "dashboard.get_started.item.profile": "Configura tu perfil",
            "dashboard.get_started.item.notifications": "Activa notificaciones",
            "dashboard.air_metrics": "Métricas del aire",
            "dashboard.metric.ozone": "Ozono",
            "dashboard.metric.humidity": "Humedad",
            "dashboard.do_now": "Qué hacer ahora",
            "dashboard.safe_windows": "Ventanas seguras",
            "planner.title": "Plan diario",
            "planner.refresh": "Actualizar plan",
            "symptoms.title": "Registro de síntomas",
            "symptoms.submit": "Enviar síntomas",
            "settings.help_title": "Ayuda",
            "settings.help_open": "Guía HiAir",
            "settings.language_ru": "Ruso",
            "settings.language_en": "Inglés",
            "settings.language_es": "Español",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Francés",
            "settings.ai_guide_open": "Asistente IA",
            "ai_guide.title": "Asistente IA de HiAir",
            "ai_guide.placeholder": "Pregunta cómo usar la app...",
            "ai_guide.send": "Preguntar",
            "ai_guide.clear": "Nuevo chat",
            "ai_guide.greeting": "Hola. Soy tu asistente IA de HiAir. Haz una pregunta y te responderé con pasos claros.",
            "ai_guide.subtitle": "Puedo guiarte y abrir la pantalla correcta",
            "ai_guide.language_hint": "Respondo en el idioma de la app:",
            "ai_guide.user_label": "Tú",
            "ai_guide.assistant_label": "Asistente HiAir",
            "ai_guide.followup": "¿Necesitas más detalle? Haz una pregunta adicional y lo detallo paso a paso.",
            "ai_guide.action.open_dashboard": "Abrir Inicio",
            "ai_guide.action.open_planner": "Abrir Plan",
            "ai_guide.action.open_insights": "Abrir Insights",
            "ai_guide.action.open_symptoms": "Abrir Síntomas",
            "ai_guide.action.open_notifications": "Abrir Ajustes",
            "ai_guide.action.open_account": "Abrir Cuenta",
            "ai_guide.action.open_onboarding": "Iniciar onboarding",
            "ai_guide.suggestion.onboarding": "¿Cómo empiezo a usar la app?",
            "ai_guide.suggestion.risk": "¿Cómo interpreto Risk, AQI y PM2.5?",
            "ai_guide.suggestion.safe_windows": "¿Cómo uso las ventanas seguras?",
            "ai_guide.suggestion.notifications": "¿Cómo activo las notificaciones?",
            "ai_guide.suggestion.symptoms": "¿Cómo registro síntomas?",
            "ai_guide.suggestion.account": "¿Cómo gestiono mi cuenta y datos?",
            "ai_guide.intent.onboarding.title": "Cómo empezar con HiAir:",
            "ai_guide.intent.onboarding.step1": "Inicia sesión o regístrate en la pantalla de cuenta.",
            "ai_guide.intent.onboarding.step2": "Completa el onboarding y elige para quién usas HiAir.",
            "ai_guide.intent.onboarding.step3": "En Inicio, revisa Risk Score y la lista “Cómo empezar”.",
            "ai_guide.intent.onboarding.step4": "Abre Plan y revisa las ventanas seguras de hoy.",
            "ai_guide.intent.risk.title": "Cómo interpretar las métricas de riesgo:",
            "ai_guide.intent.risk.step1": "Empieza por Risk Score: es tu riesgo general personalizado.",
            "ai_guide.intent.risk.step2": "AQI muestra la carga total de contaminación: cuanto más alto, peor aire.",
            "ai_guide.intent.risk.step3": "PM2.5 y ozono muestran factores que suelen empeorar la respiración.",
            "ai_guide.intent.risk.step4": "Con riesgo alto, sigue recomendaciones y planifica con ventanas seguras.",
            "ai_guide.intent.planner.title": "Cómo usar el pronóstico y las ventanas seguras:",
            "ai_guide.intent.planner.step1": "Abre la pestaña Plan.",
            "ai_guide.intent.planner.step2": "Revisa el riesgo por hora e identifica intervalos de menor riesgo.",
            "ai_guide.intent.planner.step3": "Mueve paseos, deporte o ventilación a las ventanas seguras.",
            "ai_guide.intent.planner.step4": "Si no hay ventanas, reduce actividad exterior y revisa más tarde.",
            "ai_guide.intent.notifications.title": "Cómo configurar notificaciones:",
            "ai_guide.intent.notifications.step1": "Abre Ajustes > Notificaciones.",
            "ai_guide.intent.notifications.step2": "Activa push y, si quieres, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Define umbral de alerta y horas de silencio según tu rutina.",
            "ai_guide.intent.notifications.step4": "Guarda ajustes y confirma que el checklist está marcado.",
            "ai_guide.intent.symptoms.title": "Cómo registrar síntomas y usar insights:",
            "ai_guide.intent.symptoms.step1": "Abre Síntomas y registra tu estado con regularidad.",
            "ai_guide.intent.symptoms.step2": "Usa botones rápidos cuando necesites un registro inmediato.",
            "ai_guide.intent.symptoms.step3": "Con más datos, abre Insights para ver patrones personales.",
            "ai_guide.intent.symptoms.step4": "Usa esos patrones junto al clima para planificar tu día.",
            "ai_guide.intent.account.title": "Cómo gestionar cuenta, perfil y privacidad:",
            "ai_guide.intent.account.step1": "En Ajustes revisa User ID, idioma y perfil por defecto.",
            "ai_guide.intent.account.step2": "Usa “Exportar mis datos” cuando necesites copia de privacidad.",
            "ai_guide.intent.account.step3": "Puedes cerrar sesión o eliminar cuenta cuando sea necesario.",
            "ai_guide.intent.account.step4": "Después de cambios, sincroniza desde el botón inferior.",
            "ai_guide.intent.fallback.title": "Plan universal para cualquier pregunta:",
            "ai_guide.intent.fallback.step1": "Describe qué quieres hacer en la app.",
            "ai_guide.intent.fallback.step2": "Dime en qué pantalla estás ahora.",
            "ai_guide.intent.fallback.step3": "Te daré el camino exacto, botón por botón.",
            "ai_guide.intent.fallback.step4": "Si algo falla, envía el texto del error y te ayudo a corregirlo.",
            "guide.title": "Guía HiAir",
            "guide.what_is_title": "Qué es HiAir",
            "guide.problems_title": "Qué problemas resuelve",
            "guide.for_whom_title": "Para quién es útil",
            "guide.read_dashboard_title": "Cómo leer la pantalla principal",
            "guide.risk_title": "Qué significa Risk Score",
            "guide.metrics_title": "Qué son AQI, PM2.5, ozono, humedad y calor",
            "guide.hourly_title": "Cómo usar el pronóstico por hora",
            "guide.safe_windows_title": "Qué son las ventanas seguras",
            "guide.symptoms_title": "Cómo usar el registro de síntomas",
            "guide.notifications_title": "Cómo configurar notificaciones",
            "guide.high_risk_title": "Qué hacer con riesgo alto",
            "guide.not_doctor_title": "Por qué HiAir no sustituye al médico",
            "guide.faq_title": "Preguntas frecuentes",
        ],
        "it": [
            "tab.dashboard": "Home",
            "tab.planner": "Piano",
            "tab.insights": "Insights",
            "tab.symptoms": "Sintomi",
            "tab.settings": "Impostazioni",
            "title.settings": "Impostazioni",
            "auth.title": "Account HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Password (min. 12 caratteri, A/a/0-9/simbolo)",
            "auth.sign_up": "Registrati",
            "auth.log_in": "Accedi",
            "auth.enter_email": "Inserisci email.",
            "auth.password_short": "La password deve avere almeno 12 caratteri.",
            "onboarding.start": "Inizia",
            "onboarding.next": "Avanti",
            "onboarding.back": "Indietro",
            "onboarding.step1.title": "HiAir e il tuo assistente per calore e qualita dell'aria",
            "onboarding.step1.body": "HiAir ti aiuta a capire quando il caldo e l'aria esterna possono essere rischiosi per te.",
            "onboarding.step2.title": "Quali problemi risolve HiAir",
            "onboarding.step3.title": "Per chi usi HiAir?",
            "onboarding.step4.title": "Cosa controllare ogni giorno",
            "onboarding.step5.title": "Perché i permessi sono importanti",
            "onboarding.step6.title": "Tutto pronto",
            "onboarding.open_forecast": "Apri la mia previsione",
            "dashboard.title": "Intelligenza quotidiana dell'aria",
            "dashboard.get_started.title": "Come iniziare",
            "dashboard.get_started.hide": "Nascondi",
            "dashboard.get_started.item.risk": "Controlla il livello di rischio attuale",
            "dashboard.get_started.item.hourly": "Apri la previsione oraria",
            "dashboard.get_started.item.recommendations": "Leggi le raccomandazioni",
            "dashboard.get_started.item.profile": "Configura il profilo",
            "dashboard.get_started.item.notifications": "Attiva le notifiche",
            "dashboard.air_metrics": "Metriche dell'aria",
            "dashboard.metric.ozone": "Ozono",
            "dashboard.metric.humidity": "Umidita",
            "dashboard.do_now": "Cosa fare ora",
            "dashboard.safe_windows": "Finestre sicure",
            "planner.title": "Piano giornaliero",
            "planner.refresh": "Aggiorna piano",
            "symptoms.title": "Registro sintomi",
            "symptoms.submit": "Invia sintomi",
            "settings.help_title": "Aiuto",
            "settings.help_open": "Guida HiAir",
            "settings.language_ru": "Russo",
            "settings.language_en": "Inglese",
            "settings.language_es": "Spagnolo",
            "settings.language_it": "Italiano",
            "settings.language_fr": "Francese",
            "settings.ai_guide_open": "Assistente IA",
            "ai_guide.title": "Assistente IA di HiAir",
            "ai_guide.placeholder": "Chiedi come usare l'app...",
            "ai_guide.send": "Chiedi",
            "ai_guide.clear": "Nuova chat",
            "ai_guide.greeting": "Ciao. Sono il tuo assistente IA di HiAir. Fai una domanda e ti risponderò con passaggi chiari.",
            "ai_guide.subtitle": "Posso guidarti e aprire la schermata corretta",
            "ai_guide.language_hint": "Rispondo nella lingua dell'app:",
            "ai_guide.user_label": "Tu",
            "ai_guide.assistant_label": "Assistente HiAir",
            "ai_guide.followup": "Serve più dettaglio? Fai una domanda di follow-up e lo spiego passo passo.",
            "ai_guide.action.open_dashboard": "Apri Home",
            "ai_guide.action.open_planner": "Apri Piano",
            "ai_guide.action.open_insights": "Apri Insights",
            "ai_guide.action.open_symptoms": "Apri Sintomi",
            "ai_guide.action.open_notifications": "Apri Impostazioni",
            "ai_guide.action.open_account": "Apri Account",
            "ai_guide.action.open_onboarding": "Avvia onboarding",
            "ai_guide.suggestion.onboarding": "Come inizio a usare l'app?",
            "ai_guide.suggestion.risk": "Come leggo Risk, AQI e PM2.5?",
            "ai_guide.suggestion.safe_windows": "Come uso le finestre sicure?",
            "ai_guide.suggestion.notifications": "Come attivo le notifiche?",
            "ai_guide.suggestion.symptoms": "Come registro i sintomi?",
            "ai_guide.suggestion.account": "Come gestisco account e dati?",
            "ai_guide.intent.onboarding.title": "Come iniziare con HiAir:",
            "ai_guide.intent.onboarding.step1": "Accedi o registrati nella schermata account.",
            "ai_guide.intent.onboarding.step2": "Completa onboarding e scegli per chi usi HiAir.",
            "ai_guide.intent.onboarding.step3": "In Home controlla Risk Score e lista “Come iniziare”.",
            "ai_guide.intent.onboarding.step4": "Apri Piano e verifica le finestre sicure di oggi.",
            "ai_guide.intent.risk.title": "Come leggere le metriche di rischio:",
            "ai_guide.intent.risk.step1": "Parti da Risk Score: e il tuo rischio complessivo personalizzato.",
            "ai_guide.intent.risk.step2": "AQI mostra il carico totale di inquinamento: piu alto, aria peggiore.",
            "ai_guide.intent.risk.step3": "PM2.5 e ozono indicano fattori che peggiorano il respiro.",
            "ai_guide.intent.risk.step4": "Con rischio alto, segui le raccomandazioni e usa finestre sicure.",
            "ai_guide.intent.planner.title": "Come usare previsione e finestre sicure:",
            "ai_guide.intent.planner.step1": "Apri la scheda Piano.",
            "ai_guide.intent.planner.step2": "Controlla rischio orario e trova intervalli a rischio minore.",
            "ai_guide.intent.planner.step3": "Sposta passeggiate, sport o ventilazione nelle finestre sicure.",
            "ai_guide.intent.planner.step4": "Se non ci sono finestre, riduci attivita esterna e ricontrolla.",
            "ai_guide.intent.notifications.title": "Come configurare le notifiche:",
            "ai_guide.intent.notifications.step1": "Apri Impostazioni > Notifiche.",
            "ai_guide.intent.notifications.step2": "Attiva push e, se serve, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Imposta soglia alert e ore silenziose per la tua routine.",
            "ai_guide.intent.notifications.step4": "Salva impostazioni e verifica checklist completata.",
            "ai_guide.intent.symptoms.title": "Come registrare sintomi e usare insights:",
            "ai_guide.intent.symptoms.step1": "Apri Sintomi e registra regolarmente il tuo stato.",
            "ai_guide.intent.symptoms.step2": "Usa pulsanti rapidi quando serve un log veloce.",
            "ai_guide.intent.symptoms.step3": "Con piu dati, apri Insights per pattern personali.",
            "ai_guide.intent.symptoms.step4": "Usa i pattern con meteo e aria per pianificare la giornata.",
            "ai_guide.intent.account.title": "Come gestire account, profilo e privacy:",
            "ai_guide.intent.account.step1": "In Impostazioni controlla User ID, lingua e profilo predefinito.",
            "ai_guide.intent.account.step2": "Usa “Esporta i miei dati” per una copia privacy.",
            "ai_guide.intent.account.step3": "Puoi uscire o eliminare account quando necessario.",
            "ai_guide.intent.account.step4": "Dopo le modifiche, sincronizza con il pulsante in basso.",
            "ai_guide.intent.fallback.title": "Piano universale per qualsiasi domanda:",
            "ai_guide.intent.fallback.step1": "Descrivi cosa vuoi fare nell'app.",
            "ai_guide.intent.fallback.step2": "Dimmi in quale schermata ti trovi.",
            "ai_guide.intent.fallback.step3": "Ti darò il percorso esatto, pulsante per pulsante.",
            "ai_guide.intent.fallback.step4": "Se qualcosa non funziona, invia il testo dell'errore e ti aiuto.",
            "guide.title": "Guida HiAir",
            "guide.what_is_title": "Che cos'e HiAir",
            "guide.problems_title": "Quali problemi risolve",
            "guide.for_whom_title": "Per chi e utile",
            "guide.read_dashboard_title": "Come leggere la schermata principale",
            "guide.risk_title": "Cosa significa Risk Score",
            "guide.metrics_title": "Cosa sono AQI, PM2.5, ozono, umidita e calore",
            "guide.hourly_title": "Come usare la previsione oraria",
            "guide.safe_windows_title": "Cosa sono le finestre sicure",
            "guide.symptoms_title": "Come usare il registro sintomi",
            "guide.notifications_title": "Come configurare le notifiche",
            "guide.high_risk_title": "Cosa fare con rischio alto",
            "guide.not_doctor_title": "Perché HiAir non sostituisce il medico",
            "guide.faq_title": "Domande frequenti",
        ],
        "fr": [
            "tab.dashboard": "Accueil",
            "tab.planner": "Plan",
            "tab.insights": "Insights",
            "tab.symptoms": "Symptomes",
            "tab.settings": "Parametres",
            "title.settings": "Parametres",
            "auth.title": "Compte HiAir",
            "brand.tagline": "Breathe better. Live better.",
            "auth.email": "Email",
            "auth.password": "Mot de passe (min. 12 caracteres, A/a/0-9/symbole)",
            "auth.sign_up": "S'inscrire",
            "auth.log_in": "Se connecter",
            "auth.enter_email": "Entrez votre email.",
            "auth.password_short": "Le mot de passe doit contenir au moins 12 caracteres.",
            "onboarding.start": "Commencer",
            "onboarding.next": "Suivant",
            "onboarding.back": "Retour",
            "onboarding.step1.title": "HiAir est votre assistant chaleur et qualite de l'air",
            "onboarding.step1.body": "HiAir vous aide a comprendre quand la chaleur et l'air exterieur peuvent etre risqués pour vous.",
            "onboarding.step2.title": "Quels problemes HiAir resout",
            "onboarding.step3.title": "Pour qui utilisez-vous HiAir ?",
            "onboarding.step4.title": "Que verifier chaque jour",
            "onboarding.step5.title": "Pourquoi les autorisations comptent",
            "onboarding.step6.title": "C'est pret",
            "onboarding.open_forecast": "Ouvrir ma prevision",
            "dashboard.title": "Intelligence quotidienne de l'air",
            "dashboard.get_started.title": "Comment commencer",
            "dashboard.get_started.hide": "Masquer",
            "dashboard.get_started.item.risk": "Verifier le niveau de risque actuel",
            "dashboard.get_started.item.hourly": "Ouvrir la prevision horaire",
            "dashboard.get_started.item.recommendations": "Lire les recommandations",
            "dashboard.get_started.item.profile": "Configurer le profil",
            "dashboard.get_started.item.notifications": "Activer les notifications",
            "dashboard.air_metrics": "Indicateurs de l'air",
            "dashboard.metric.ozone": "Ozone",
            "dashboard.metric.humidity": "Humidite",
            "dashboard.do_now": "Que faire maintenant",
            "dashboard.safe_windows": "Creneaux surs",
            "planner.title": "Plan quotidien",
            "planner.refresh": "Actualiser le plan",
            "symptoms.title": "Journal des symptomes",
            "symptoms.submit": "Envoyer les symptomes",
            "settings.help_title": "Aide",
            "settings.help_open": "Guide HiAir",
            "settings.language_ru": "Russe",
            "settings.language_en": "Anglais",
            "settings.language_es": "Espagnol",
            "settings.language_it": "Italien",
            "settings.language_fr": "Français",
            "settings.ai_guide_open": "Assistant IA",
            "ai_guide.title": "Assistant IA HiAir",
            "ai_guide.placeholder": "Pose une question sur l'application...",
            "ai_guide.send": "Demander",
            "ai_guide.clear": "Nouveau chat",
            "ai_guide.greeting": "Bonjour. Je suis ton assistant IA HiAir. Pose une question et je répondrai avec des étapes claires.",
            "ai_guide.subtitle": "Je peux te guider et ouvrir le bon écran",
            "ai_guide.language_hint": "Je réponds dans la langue de l'application :",
            "ai_guide.user_label": "Vous",
            "ai_guide.assistant_label": "Assistant HiAir",
            "ai_guide.followup": "Besoin de plus de détails ? Pose une question de suivi et je détaillerai étape par étape.",
            "ai_guide.action.open_dashboard": "Ouvrir Accueil",
            "ai_guide.action.open_planner": "Ouvrir Plan",
            "ai_guide.action.open_insights": "Ouvrir Insights",
            "ai_guide.action.open_symptoms": "Ouvrir Symptômes",
            "ai_guide.action.open_notifications": "Ouvrir Paramètres",
            "ai_guide.action.open_account": "Ouvrir Compte",
            "ai_guide.action.open_onboarding": "Lancer l'onboarding",
            "ai_guide.suggestion.onboarding": "Comment commencer à utiliser l'app ?",
            "ai_guide.suggestion.risk": "Comment lire Risk, AQI et PM2.5 ?",
            "ai_guide.suggestion.safe_windows": "Comment utiliser les créneaux sûrs ?",
            "ai_guide.suggestion.notifications": "Comment activer les notifications ?",
            "ai_guide.suggestion.symptoms": "Comment enregistrer les symptômes ?",
            "ai_guide.suggestion.account": "Comment gérer compte et données ?",
            "ai_guide.intent.onboarding.title": "Comment demarrer avec HiAir :",
            "ai_guide.intent.onboarding.step1": "Connectez-vous ou inscrivez-vous sur l'ecran compte.",
            "ai_guide.intent.onboarding.step2": "Terminez l'onboarding et choisissez pour qui vous utilisez HiAir.",
            "ai_guide.intent.onboarding.step3": "Sur Accueil, verifiez Risk Score et la liste “Comment commencer”.",
            "ai_guide.intent.onboarding.step4": "Ouvrez Plan et verifiez les creneaux surs du jour.",
            "ai_guide.intent.risk.title": "Comment lire les indicateurs de risque :",
            "ai_guide.intent.risk.step1": "Commencez par Risk Score : c'est votre risque global personnalise.",
            "ai_guide.intent.risk.step2": "AQI montre la charge totale de pollution : plus c'est haut, pire est l'air.",
            "ai_guide.intent.risk.step3": "PM2.5 et ozone indiquent les facteurs qui aggravent la respiration.",
            "ai_guide.intent.risk.step4": "En risque eleve, suivez recommandations et creneaux surs.",
            "ai_guide.intent.planner.title": "Comment utiliser la prevision et les creneaux surs :",
            "ai_guide.intent.planner.step1": "Ouvrez l'onglet Plan.",
            "ai_guide.intent.planner.step2": "Verifiez le risque horaire et trouvez les intervalles plus favorables.",
            "ai_guide.intent.planner.step3": "Planifiez marche, sport ou ventilation pendant les creneaux surs.",
            "ai_guide.intent.planner.step4": "S'il n'y a pas de creneaux, reduisez l'activite exterieure et reverifiez.",
            "ai_guide.intent.notifications.title": "Comment configurer les notifications :",
            "ai_guide.intent.notifications.step1": "Ouvrez Parametres > Notifications.",
            "ai_guide.intent.notifications.step2": "Activez push et, si besoin, Morning Briefing.",
            "ai_guide.intent.notifications.step3": "Reglez seuil d'alerte et heures calmes selon votre routine.",
            "ai_guide.intent.notifications.step4": "Sauvegardez et confirmez la completion de la checklist.",
            "ai_guide.intent.symptoms.title": "Comment enregistrer les symptomes et utiliser les insights :",
            "ai_guide.intent.symptoms.step1": "Ouvrez Symptomes et enregistrez votre etat regulierement.",
            "ai_guide.intent.symptoms.step2": "Utilisez les boutons rapides pour un log immediate.",
            "ai_guide.intent.symptoms.step3": "Avec plus de donnees, ouvrez Insights pour voir vos patterns.",
            "ai_guide.intent.symptoms.step4": "Utilisez ces patterns avec meteo/air pour planifier la journee.",
            "ai_guide.intent.account.title": "Comment gerer compte, profil et confidentialite :",
            "ai_guide.intent.account.step1": "Dans Parametres, verifiez User ID, langue et profil par defaut.",
            "ai_guide.intent.account.step2": "Utilisez “Exporter mes donnees” pour une copie confidentialite.",
            "ai_guide.intent.account.step3": "Vous pouvez vous deconnecter ou supprimer le compte si necessaire.",
            "ai_guide.intent.account.step4": "Apres changements, synchronisez via le bouton en bas.",
            "ai_guide.intent.fallback.title": "Plan universel pour toute question :",
            "ai_guide.intent.fallback.step1": "Décrivez ce que vous voulez faire dans l'app.",
            "ai_guide.intent.fallback.step2": "Dites-moi sur quel écran vous êtes.",
            "ai_guide.intent.fallback.step3": "Je vous donnerai le chemin exact, bouton par bouton.",
            "ai_guide.intent.fallback.step4": "Si quelque chose échoue, envoyez le texte d'erreur et je vous aiderai.",
            "guide.title": "Guide HiAir",
            "guide.what_is_title": "Qu'est-ce que HiAir",
            "guide.problems_title": "Quels problemes l'application resout",
            "guide.for_whom_title": "Pour qui HiAir est utile",
            "guide.read_dashboard_title": "Comment lire l'ecran principal",
            "guide.risk_title": "Que signifie Risk Score",
            "guide.metrics_title": "Que signifient AQI, PM2.5, ozone, humidite et chaleur",
            "guide.hourly_title": "Comment utiliser la prevision horaire",
            "guide.safe_windows_title": "Que sont les creneaux surs",
            "guide.symptoms_title": "Comment utiliser le journal des symptomes",
            "guide.notifications_title": "Comment configurer les notifications",
            "guide.high_risk_title": "Que faire en cas de risque eleve",
            "guide.not_doctor_title": "Pourquoi HiAir ne remplace pas un medecin",
            "guide.faq_title": "FAQ",
        ],
    ]
}

extension AppSession {
    func l(_ key: String) -> String {
        HiAirL10n.t(key, lang: preferredLanguage)
    }
}
