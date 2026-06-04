"""Personal load score from wearable aggregates — wellness-only, no medical claims."""

from __future__ import annotations

from dataclasses import dataclass, field


FORBIDDEN_PHRASES = (
    "тахикард",
    "сердечн",
    "больниц",
    "диагност",
    "emergency",
    "diagnosis",
    "heart disease",
    "call 911",
)


@dataclass
class PersonalLoadInput:
    steps_today: int | None = None
    steps_last_hour: int | None = None
    steps_last_3_hours: int | None = None
    heart_rate_avg: float | None = None
    heart_rate_max: float | None = None
    resting_heart_rate: float | None = None
    resting_heart_rate_baseline_7d: float | None = None
    resting_heart_rate_baseline_30d: float | None = None
    heat_index: float | None = None
    temperature: float | None = None
    humidity: float | None = None
    aqi: int | None = None
    ozone: float | None = None
    pm25: float | None = None
    symptoms: list[str] = field(default_factory=list)
    consent_active: bool = True


@dataclass
class PersonalLoadResult:
    score: int
    level: str
    reason_codes: list[str]
    explanations: list[str]


def _has_wearable_data(data: PersonalLoadInput) -> bool:
    return any(
        value is not None
        for value in (
            data.steps_today,
            data.steps_last_hour,
            data.steps_last_3_hours,
            data.heart_rate_avg,
            data.heart_rate_max,
            data.resting_heart_rate,
        )
    )


def compute_personal_load_score(data: PersonalLoadInput) -> PersonalLoadResult:
    if not data.consent_active or not _has_wearable_data(data):
        return PersonalLoadResult(
            score=0,
            level="none",
            reason_codes=[],
            explanations=["Данных о здоровье нет — анализ основан на погоде и качестве воздуха."],
        )

    raw_points = 0
    reason_codes: list[str] = []
    explanations: list[str] = []

    heat_index = data.heat_index if data.heat_index is not None else (data.temperature or 0)
    aqi = data.aqi or 0
    steps = data.steps_today or 0
    steps_hour = data.steps_last_hour or 0

    # Steps + heat
    if steps > 10_000 and heat_index >= 34:
        raw_points += 20
        reason_codes.append("high_steps_extreme_heat")
        explanations.append("Сегодня высокая активность на фоне жары.")
    elif steps > 8_000 and heat_index >= 32:
        raw_points += 15
        reason_codes.append("high_steps_high_heat")
        explanations.append("Сегодня высокая активность на фоне жары.")
    elif steps > 6_000 and heat_index >= 30:
        raw_points += 10
        reason_codes.append("elevated_steps_heat")
        explanations.append("Сегодня высокая активность на фоне жары.")

    # Last hour
    if steps_hour > 2_000 and heat_index >= 30:
        raw_points += 10
        reason_codes.append("recent_steps_heat")
        explanations.append("Недавно была высокая активность при повышенной температуре.")
    if steps_hour > 2_500 and aqi >= 100:
        raw_points += 10
        reason_codes.append("recent_steps_poor_air")
        explanations.append("При текущем AQI лучше снизить интенсивную активность на улице.")

    # Heart rate max + heat
    if data.heart_rate_max is not None and data.heart_rate_max > 130 and heat_index >= 30:
        raw_points += 10
        reason_codes.append("elevated_hr_max_heat")
        explanations.append("Пульс выше вашей обычной нормы.")

    # Heart rate avg elevated + environment
    if data.heart_rate_avg is not None and data.heart_rate_avg > 100:
        if heat_index >= 30 or aqi >= 100:
            raw_points += 10
            reason_codes.append("elevated_hr_avg_environment")
            explanations.append("Пульс выше вашей обычной нормы.")

    # Resting HR vs baseline
    if data.resting_heart_rate is not None:
        if (
            data.resting_heart_rate_baseline_7d is not None
            and data.resting_heart_rate > data.resting_heart_rate_baseline_7d + 8
        ):
            raw_points += 15
            reason_codes.append("resting_hr_above_7d_baseline")
            explanations.append("Пульс в покое выше вашей обычной нормы.")
        elif (
            data.resting_heart_rate_baseline_30d is not None
            and data.resting_heart_rate > data.resting_heart_rate_baseline_30d + 10
        ):
            raw_points += 15
            reason_codes.append("resting_hr_above_30d_baseline")
            explanations.append("Пульс в покое выше вашей обычной нормы.")

    # AQI + activity
    if aqi >= 150 and steps > 4_000:
        raw_points += 15
        reason_codes.append("poor_air_moderate_activity")
        explanations.append("При текущем AQI лучше снизить интенсивную активность на улице.")
    elif aqi >= 100 and steps > 6_000:
        raw_points += 10
        reason_codes.append("elevated_air_high_activity")
        explanations.append("При текущем AQI лучше снизить интенсивную активность на улице.")

    # Symptom context (no duplicate scoring)
    if data.symptoms and raw_points >= 10:
        reason_codes.append("symptoms_with_load")
        explanations.append("Организм может быть перегружен — рекомендуем снизить активность.")

    score = min(100, raw_points)
    level = _level_from_score(score)
    explanations = _sanitize_explanations(list(dict.fromkeys(explanations)))
    if score > 0 and not any("wellness" in e.lower() or "диагноз" in e.lower() for e in explanations):
        explanations.append("HiAir даёт wellness-рекомендации, а не медицинский диагноз.")

    return PersonalLoadResult(
        score=score,
        level=level,
        reason_codes=sorted(set(reason_codes)),
        explanations=explanations,
    )


def _level_from_score(score: int) -> str:
    if score <= 0:
        return "none"
    if score < 25:
        return "low"
    if score < 50:
        return "moderate"
    if score < 75:
        return "elevated"
    return "high"


def _sanitize_explanations(explanations: list[str]) -> list[str]:
    clean: list[str] = []
    for text in explanations:
        lower = text.lower()
        if any(phrase in lower for phrase in FORBIDDEN_PHRASES):
            continue
        clean.append(text)
    return clean or ["HiAir даёт wellness-рекомендации, а не медицинский диагноз."]


def environmental_numeric_score(feels_like: float, humidity: float, aqi: int, pm25: float, ozone: float) -> int:
    """Map environment to 0-100 for weighted final score."""
    score = 0
    if feels_like >= 40:
        score += 35
    elif feels_like >= 34:
        score += 25
    elif feels_like >= 29:
        score += 15
    else:
        score += 5

    if humidity >= 80:
        score += 10
    elif humidity >= 65:
        score += 7
    elif humidity >= 50:
        score += 4

    if aqi >= 201:
        score += 30
    elif aqi >= 151:
        score += 22
    elif aqi >= 101:
        score += 14
    elif aqi >= 51:
        score += 8

    if pm25 >= 55:
        score += 12
    elif pm25 >= 35:
        score += 8

    if ozone >= 120:
        score += 8
    elif ozone >= 90:
        score += 6

    return min(100, score)


def symptom_numeric_score(symptoms: list[str]) -> int:
    if not symptoms:
        return 0
    return min(100, len(symptoms) * 12)


def compute_weighted_final_score(
    environmental_score: int,
    personal_load_score: int,
    symptom_score: int,
) -> int:
    blended = (
        environmental_score * 0.65
        + personal_load_score * 0.25
        + symptom_score * 0.10
    )
    return min(100, max(0, int(round(blended))))


def personal_load_risk_bump(score: int) -> int:
    """Discrete bump for air_risk_engine overall_order (0..1)."""
    if score >= 50:
        return 1
    if score >= 25:
        return 1
    return 0
