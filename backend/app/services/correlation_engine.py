from __future__ import annotations

import math
import random
from datetime import datetime, timezone

from app.models.air import PersonalPatternInsight
from app.services.localization import normalize_language

MIN_POINTS = 14
MIN_ABS_R = 0.3
MAX_INSIGHTS = 8
PERMUTATION_ITERATIONS = 800


def compute_personal_patterns(
    samples: list[dict[str, float | None]],
    language: str = "ru",
) -> list[PersonalPatternInsight]:
    if len(samples) < MIN_POINTS:
        return []

    factors_a = ("pm25", "ozone", "temperature", "humidity", "aqi")
    factors_b = (
        "cough_count",
        "wheeze_count",
        "headache_count",
        "fatigue_count",
        "sleep_quality",
        "steps",
        "resting_heart_rate",
        "sleep_minutes",
    )
    lang = normalize_language(language)

    insights: list[PersonalPatternInsight] = []
    for factor_a in factors_a:
        for factor_b in factors_b:
            paired = _paired_non_null(samples, factor_a, factor_b)
            if len(paired) < MIN_POINTS:
                continue
            series_a = [a for a, _ in paired]
            series_b = [b for _, b in paired]
            r = _pearson(series_a, series_b)
            if r is None or abs(r) < MIN_ABS_R:
                continue
            p_value = _permutation_p_value(series_a, series_b, observed_r=r, iterations=PERMUTATION_ITERATIONS)
            if p_value >= 0.05:
                continue
            insights.append(
                PersonalPatternInsight(
                    factorA=factor_a,
                    factorB=factor_b,
                    coefficient=round(r, 3),
                    pValue=round(p_value, 4),
                    sampleSize=len(paired),
                    humanReadableText=_render_text(
                        factor_a=factor_a,
                        factor_b=factor_b,
                        coefficient=r,
                        language=lang,
                    ),
                )
            )

    insights.sort(key=lambda item: abs(item.coefficient), reverse=True)
    return insights[:MAX_INSIGHTS]


def _paired_non_null(
    samples: list[dict[str, float | None]],
    factor_a: str,
    factor_b: str,
) -> list[tuple[float, float]]:
    paired: list[tuple[float, float]] = []
    for row in samples:
        a = row.get(factor_a)
        b = row.get(factor_b)
        if a is None or b is None:
            continue
        paired.append((float(a), float(b)))
    return paired


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _pearson(x: list[float], y: list[float]) -> float | None:
    if len(x) != len(y) or len(x) < 2:
        return None
    mean_x = sum(x) / len(x)
    mean_y = sum(y) / len(y)
    dx = [value - mean_x for value in x]
    dy = [value - mean_y for value in y]
    numerator = sum(a * b for a, b in zip(dx, dy))
    denominator = math.sqrt(sum(a * a for a in dx) * sum(b * b for b in dy))
    if denominator == 0:
        return None
    return numerator / denominator


def _permutation_p_value(
    x: list[float],
    y: list[float],
    observed_r: float,
    iterations: int,
) -> float:
    rng = random.Random(42)
    target = abs(observed_r)
    y_values = list(y)
    extreme = 0
    for _ in range(iterations):
        rng.shuffle(y_values)
        candidate = _pearson(x, y_values)
        if candidate is None:
            continue
        if abs(candidate) >= target:
            extreme += 1
    return (extreme + 1) / (iterations + 1)


def _render_text(factor_a: str, factor_b: str, coefficient: float, language: str) -> str:
    if language == "en":
        direction = "more often together" if coefficient > 0 else "in opposite directions"
        return (
            f"An association was observed between {factor_a} and {factor_b} "
            f"({direction}; r={coefficient:.2f}). This is not proven causation."
        )
    direction_ru = "чаще вместе" if coefficient > 0 else "в противоположных направлениях"
    return (
        f"Наблюдается связь между {factor_a} и {factor_b} "
        f"({direction_ru}; r={coefficient:.2f}). Это не доказанная причинно-следственная связь."
    )
