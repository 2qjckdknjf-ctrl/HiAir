from app.services.localization import normalize_language, t


def _risk_actions(risk_level: str, language: str) -> tuple[str, list[str]]:
    lang = normalize_language(language)
    if risk_level == "very_high":
        return (
            t(lang, "daily.very_high.summary"),
            [
                t(lang, "daily.very_high.action1"),
                t(lang, "daily.very_high.action2"),
                t(lang, "daily.very_high.action3"),
            ],
        )
    if risk_level == "high":
        return (
            t(lang, "daily.high.summary"),
            [
                t(lang, "daily.high.action1"),
                t(lang, "daily.high.action2"),
                t(lang, "daily.high.action3"),
            ],
        )
    if risk_level in ("medium", "moderate"):
        return (
            t(lang, "daily.medium.summary"),
            [
                t(lang, "daily.medium.action1"),
                t(lang, "daily.medium.action2"),
            ],
        )
    return (
        t(lang, "daily.low.summary"),
        [
            t(lang, "daily.low.action1"),
            t(lang, "daily.low.action2"),
        ],
    )


def _symptom_actions(symptom_stats: dict[str, int], language: str) -> list[str]:
    lang = normalize_language(language)
    actions: list[str] = []
    if symptom_stats["wheeze_count"] >= 1:
        actions.append(t(lang, "daily.symptom.wheeze"))
    if symptom_stats["cough_count"] >= 2:
        actions.append(t(lang, "daily.symptom.cough"))
    if symptom_stats["fatigue_count"] >= 2:
        actions.append(t(lang, "daily.symptom.fatigue"))
    if symptom_stats["headache_count"] >= 2:
        actions.append(t(lang, "daily.symptom.headache"))
    return actions


def build_daily_recommendation(
    risk_level: str,
    symptom_stats: dict[str, int],
    language: str = "ru",
) -> tuple[str, list[str]]:
    lang = normalize_language(language)
    summary, actions = _risk_actions(risk_level, lang)
    actions.extend(_symptom_actions(symptom_stats, lang))
    return summary, actions
