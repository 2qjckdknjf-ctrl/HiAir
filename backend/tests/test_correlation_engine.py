from app.services.correlation_engine import compute_personal_patterns


def test_compute_personal_patterns_returns_insights_for_correlated_series() -> None:
    samples = []
    for day in range(20):
        pm25 = float(10 + day)
        samples.append(
            {
                "pm25": pm25,
                "ozone": float(50 + day),
                "temperature": float(20 + day * 0.2),
                "humidity": float(40 + day * 0.1),
                "aqi": float(60 + day),
                "cough_count": pm25 / 10.0,
                "wheeze_count": pm25 / 11.0,
                "headache_count": 0.2,
                "fatigue_count": 0.3,
                "sleep_quality": 5.0 - (pm25 / 20.0),
            }
        )

    insights = compute_personal_patterns(samples=samples, language="en")
    assert len(insights) >= 1
    assert any(item.factorA == "pm25" for item in insights)
    assert all(item.pValue < 0.05 for item in insights)
