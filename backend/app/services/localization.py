SUPPORTED_LANGUAGES = ("ru", "en")


def normalize_language(value: str | None) -> str:
    if not value:
        return "ru"
    lowered = value.lower().strip()
    if lowered.startswith("en"):
        return "en"
    if lowered.startswith("ru"):
        return "ru"
    return "ru"


def t(language: str, key: str, **kwargs: object) -> str:
    lang = normalize_language(language)
    template = MESSAGES.get(lang, MESSAGES["ru"]).get(key) or MESSAGES["ru"].get(key, key)
    return template.format(**kwargs)


MESSAGES: dict[str, dict[str, str]] = {
    "ru": {
        "rec.low.headline": "Сейчас условия благоприятные для обычной активности",
        "rec.low.summary": "Риск по жаре и воздуху низкий, можно следовать обычному распорядку.",
        "rec.low.action": "Поддерживайте обычный режим активности и гидратации.",
        "rec.moderate.headline": "Выбирайте активность в более безопасные часы",
        "rec.moderate.summary": "Условия умеренно рискованные, лучше планировать улицу точечно.",
        "rec.moderate.action1": "Сократите длительность прогулки или тренировки.",
        "rec.moderate.action2": "Избегайте пиковых часов жары.",
        "rec.moderate.action3": "Следите за самочувствием во время активности.",
        "rec.high.headline": "Сейчас лучше ограничить активность на улице",
        "rec.high.summary": "Жара и качество воздуха создают повышенную нагрузку именно для вашего профиля.",
        "rec.high.action1": "Отложите длительную активность до более безопасного окна.",
        "rec.high.action2": "Снизьте интенсивную физическую нагрузку.",
        "rec.high.action3": "Пейте больше воды и делайте частые паузы.",
        "rec.windows.closed": "Держите окна закрытыми до улучшения воздуха.",
        "rec.ventilate.window": "Проветрите в окно {start}-{end}.",
        "rec.ventilate.later": "Проветривание лучше отложить до снижения загрязнения.",
        "rec.profile.caution": "Для чувствительного профиля уменьшите время непрерывного пребывания на улице.",
        "alert.disabled.title": "Уведомления отключены",
        "alert.disabled.body": "Push-уведомления отключены пользователем.",
        "alert.quiet.title": "Тихие часы",
        "alert.quiet.body": "Тихие часы активны, push не отправляется.",
        "alert.nochange.title": "Нет значимого изменения",
        "alert.nochange.body": "Риск не изменился существенно.",
        "alert.duplicate.title": "Дубликат заблокирован",
        "alert.duplicate.body": "Похожий алерт был отправлен недавно.",
        "expl.fallback": "Сейчас для вас уровень риска: {risk}. {summary} Начните с действия: {action}",
        "expl.prompt.language": "Russian",
    },
    "en": {
        "rec.low.headline": "Conditions are favorable for normal activity",
        "rec.low.summary": "Heat and air risk is currently low, regular routine is acceptable.",
        "rec.low.action": "Maintain normal activity and hydration.",
        "rec.moderate.headline": "Choose safer hours for activity",
        "rec.moderate.summary": "Conditions are moderately risky, outdoor plans should be time-aware.",
        "rec.moderate.action1": "Shorten walk or workout duration.",
        "rec.moderate.action2": "Avoid peak heat hours.",
        "rec.moderate.action3": "Monitor symptoms during activity.",
        "rec.high.headline": "It is better to limit outdoor activity now",
        "rec.high.summary": "Heat and air quality create higher load for your profile.",
        "rec.high.action1": "Delay longer activity to a safer window.",
        "rec.high.action2": "Reduce high-intensity physical effort.",
        "rec.high.action3": "Hydrate frequently and take breaks.",
        "rec.windows.closed": "Keep windows closed until air quality improves.",
        "rec.ventilate.window": "Ventilate during {start}-{end}.",
        "rec.ventilate.later": "Ventilation is better postponed until pollution drops.",
        "rec.profile.caution": "For sensitive profiles, reduce continuous outdoor exposure.",
        "alert.disabled.title": "Alerts disabled",
        "alert.disabled.body": "Push alerts are disabled by user preference.",
        "alert.quiet.title": "Quiet hours",
        "alert.quiet.body": "Quiet hours are active, push is suppressed.",
        "alert.nochange.title": "No material change",
        "alert.nochange.body": "Risk has not changed significantly.",
        "alert.duplicate.title": "Duplicate blocked",
        "alert.duplicate.body": "A similar alert was sent recently.",
        "expl.fallback": "Your current risk level is {risk}. {summary} Start with: {action}",
        "expl.prompt.language": "English",
    },
}
