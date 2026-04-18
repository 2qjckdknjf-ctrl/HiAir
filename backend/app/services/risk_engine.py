from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput


def _temperature_points(temperature_c: float) -> int:
    if temperature_c >= 38:
        return 35
    if temperature_c >= 33:
        return 25
    if temperature_c >= 29:
        return 15
    return 5


def _humidity_points(humidity_percent: float) -> int:
    if humidity_percent >= 80:
        return 10
    if humidity_percent >= 65:
        return 7
    if humidity_percent >= 50:
        return 4
    return 2


def _aqi_points(aqi: int) -> int:
    if aqi >= 201:
        return 30
    if aqi >= 151:
        return 22
    if aqi >= 101:
        return 14
    if aqi >= 51:
        return 8
    return 2


def _pm25_points(pm25: float) -> int:
    if pm25 >= 55:
        return 12
    if pm25 >= 35:
        return 8
    if pm25 >= 15:
        return 4
    return 1


def _ozone_points(ozone: float) -> int:
    if ozone >= 120:
        return 8
    if ozone >= 90:
        return 6
    if ozone >= 70:
        return 4
    return 1


def _persona_modifier(persona: PersonaType) -> int:
    if persona in (PersonaType.CHILD, PersonaType.ELDERLY):
        return 12
    if persona in (PersonaType.ASTHMA, PersonaType.ALLERGY):
        return 16
    if persona in (PersonaType.RUNNER, PersonaType.WORKER):
        return 8
    return 3


def _symptom_modifier(symptoms: SymptomInput) -> int:
    points = 0
    points += 5 if symptoms.cough else 0
    points += 8 if symptoms.wheeze else 0
    points += 3 if symptoms.headache else 0
    points += 4 if symptoms.fatigue else 0
    if symptoms.sleep_quality <= 2:
        points += 5
    return points


def _risk_level(score: int) -> str:
    if score >= 80:
        return "very_high"
    if score >= 60:
        return "high"
    if score >= 35:
        return "medium"
    return "low"


def _recommendations(level: str) -> list[str]:
    if level == "very_high":
        return [
            "Avoid prolonged outdoor activity.",
            "Keep indoor air clean and hydrated.",
            "Use mask outdoors if air quality is poor.",
        ]
    if level == "high":
        return [
            "Limit outdoor exposure during peak hours.",
            "Prefer shaded or indoor activities.",
            "Monitor symptoms and rest if needed.",
        ]
    if level == "medium":
        return [
            "Plan activities in safer time windows.",
            "Stay hydrated and take regular breaks.",
        ]
    return [
        "Conditions are relatively safe.",
        "Maintain normal precautions and hydration.",
    ]


def estimate_risk(
    persona: PersonaType,
    symptoms: SymptomInput,
    environment: EnvironmentSnapshot,
) -> tuple[int, str, list[str], dict[str, int]]:
    env_component = (
        _temperature_points(environment.temperature_c)
        + _humidity_points(environment.humidity_percent)
        + _aqi_points(environment.aqi)
        + _pm25_points(environment.pm25)
        + _ozone_points(environment.ozone)
    )
    persona_component = _persona_modifier(persona)
    symptom_component = _symptom_modifier(symptoms)

    score = min(100, env_component + persona_component + symptom_component)
    level = _risk_level(score)
    recommendations = _recommendations(level)
    components = {
        "env_component": env_component,
        "persona_component": persona_component,
        "symptom_component": symptom_component,
    }
    return score, level, recommendations, components
