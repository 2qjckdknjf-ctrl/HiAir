def _risk_actions(risk_level: str) -> tuple[str, list[str]]:
    if risk_level == "very_high":
        return (
            "Conditions are very high risk right now.",
            [
                "Avoid outdoor activity unless necessary.",
                "Keep windows closed during peak pollution hours.",
                "Hydrate frequently and reduce physical load.",
            ],
        )
    if risk_level == "high":
        return (
            "Conditions are high risk.",
            [
                "Limit outdoor time and avoid peak heat hours.",
                "Use shorter outdoor intervals with breaks.",
                "Prefer indoor ventilation when air quality improves.",
            ],
        )
    if risk_level == "medium":
        return (
            "Conditions are moderate risk.",
            [
                "Plan activities during safer windows.",
                "Monitor symptoms and stop activity if they worsen.",
            ],
        )
    return (
        "Conditions are low risk.",
        [
            "Normal activity is generally acceptable.",
            "Maintain hydration and routine precautions.",
        ],
    )


def _symptom_actions(symptom_stats: dict[str, int]) -> list[str]:
    actions: list[str] = []
    if symptom_stats["wheeze_count"] >= 1:
        actions.append("Wheezing logged recently; reduce exertion and monitor breathing.")
    if symptom_stats["cough_count"] >= 2:
        actions.append("Repeated cough events detected; prioritize cleaner-air periods.")
    if symptom_stats["fatigue_count"] >= 2:
        actions.append("Fatigue trend detected; shorten workouts and increase recovery.")
    if symptom_stats["headache_count"] >= 2:
        actions.append("Headache trend detected; reduce sun exposure and stay hydrated.")
    return actions


def build_daily_recommendation(
    risk_level: str,
    symptom_stats: dict[str, int],
) -> tuple[str, list[str]]:
    summary, actions = _risk_actions(risk_level)
    actions.extend(_symptom_actions(symptom_stats))
    return summary, actions
