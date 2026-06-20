from app.models.insights import RiskBreakdownFactor, RiskBreakdownResponse
from app.models.risk import EnvironmentSnapshot, PersonaType, SymptomInput
from app.models.wearable import WearableMetricsResponse
from app.services.risk_engine import (
    _aqi_points,
    _humidity_points,
    _ozone_points,
    _persona_modifier,
    _pm25_points,
    _risk_level,
    _symptom_modifier,
    _temperature_points,
)


def _wearable_points(metrics: WearableMetricsResponse | None) -> tuple[int, list[RiskBreakdownFactor]]:
    if metrics is None:
        return 0, []

    points = 0
    factors: list[RiskBreakdownFactor] = []

    if metrics.resting_heart_rate_bpm is not None and metrics.resting_heart_rate_bpm >= 90:
        delta = 9 if metrics.resting_heart_rate_bpm >= 100 else 5
        points += delta
        factors.append(
            RiskBreakdownFactor(
                key="elevated_heart_rate",
                label_ru="высокий пульс",
                label_en="elevated heart rate",
                points=delta,
            )
        )

    sleep_score = metrics.sleep_quality_score
    if sleep_score is not None and sleep_score <= 2:
        delta = 12
        points += delta
        factors.append(
            RiskBreakdownFactor(
                key="poor_sleep",
                label_ru="плохой сон",
                label_en="poor sleep",
                points=delta,
            )
        )
    elif metrics.sleep_hours is not None and metrics.sleep_hours < 6:
        delta = 8
        points += delta
        factors.append(
            RiskBreakdownFactor(
                key="short_sleep",
                label_ru="короткий сон",
                label_en="short sleep",
                points=delta,
            )
        )

    return points, factors


def _symptom_factors(symptoms: SymptomInput) -> tuple[int, list[RiskBreakdownFactor]]:
    total = _symptom_modifier(symptoms)
    if total <= 0:
        return 0, []

    factors: list[RiskBreakdownFactor] = []
    if symptoms.cough:
        factors.append(RiskBreakdownFactor(key="cough", label_ru="кашель", label_en="cough", points=5))
    if symptoms.wheeze:
        factors.append(RiskBreakdownFactor(key="wheeze", label_ru="свистящее дыхание", label_en="wheezing", points=8))
    if symptoms.headache:
        factors.append(RiskBreakdownFactor(key="headache", label_ru="головная боль", label_en="headache", points=3))
    if symptoms.fatigue:
        factors.append(RiskBreakdownFactor(key="fatigue", label_ru="усталость", label_en="fatigue", points=4))
    if symptoms.sleep_quality <= 2:
        factors.append(
            RiskBreakdownFactor(
                key="logged_poor_sleep",
                label_ru="низкое качество сна",
                label_en="low sleep quality",
                points=5,
            )
        )

    allocated = sum(f.points for f in factors)
    if allocated != total and factors:
        factors[-1] = RiskBreakdownFactor(
            key=factors[-1].key,
            label_ru=factors[-1].label_ru,
            label_en=factors[-1].label_en,
            points=factors[-1].points + (total - allocated),
        )
    return total, factors


def build_risk_breakdown(
    *,
    profile_id: str | None,
    persona: PersonaType,
    symptoms: SymptomInput,
    environment: EnvironmentSnapshot,
    wearable: WearableMetricsResponse | None = None,
) -> RiskBreakdownResponse:
    heat_pts = _temperature_points(environment.temperature_c)
    humidity_pts = _humidity_points(environment.humidity_percent)
    aqi_pts = _aqi_points(environment.aqi)
    pm25_pts = _pm25_points(environment.pm25)
    ozone_pts = _ozone_points(environment.ozone)
    persona_pts = _persona_modifier(persona)
    symptom_pts, symptom_factors = _symptom_factors(symptoms)
    wearable_pts, wearable_factors = _wearable_points(wearable)

    env_factors: list[RiskBreakdownFactor] = []
    if heat_pts > 0:
        env_factors.append(
            RiskBreakdownFactor(key="heat", label_ru="жара", label_en="heat", points=heat_pts)
        )
    if humidity_pts > 0:
        env_factors.append(
            RiskBreakdownFactor(
                key="humidity",
                label_ru="влажность",
                label_en="humidity",
                points=humidity_pts,
            )
        )
    if aqi_pts > 0:
        env_factors.append(
            RiskBreakdownFactor(key="aqi", label_ru="AQI", label_en="AQI", points=aqi_pts)
        )
    if pm25_pts > 0:
        env_factors.append(
            RiskBreakdownFactor(key="pm25", label_ru="PM2.5", label_en="PM2.5", points=pm25_pts)
        )
    if ozone_pts > 0:
        env_factors.append(
            RiskBreakdownFactor(key="ozone", label_ru="озон/дым", label_en="ozone/smoke", points=ozone_pts)
        )

    persona_factors: list[RiskBreakdownFactor] = []
    if persona_pts > 0:
        persona_factors.append(
            RiskBreakdownFactor(
                key="persona",
                label_ru="чувствительность профиля",
                label_en="profile sensitivity",
                points=persona_pts,
            )
        )

    factors = env_factors + persona_factors + symptom_factors + wearable_factors
    raw_total = heat_pts + humidity_pts + aqi_pts + pm25_pts + ozone_pts + persona_pts + symptom_pts + wearable_pts
    total_score = min(100, raw_total)
    risk_level = _risk_level(total_score)

    return RiskBreakdownResponse(
        profile_id=profile_id,
        total_score=total_score,
        risk_level=risk_level,
        factors=[f for f in factors if f.points > 0],
    )
