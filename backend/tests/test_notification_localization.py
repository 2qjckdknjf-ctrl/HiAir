from app.models.risk import RiskEstimateResponse
from app.services.notification_service import build_notification_text


def test_notification_text_localizes_high_risk() -> None:
    risk = RiskEstimateResponse(score=78, level="high", recommendations=[], components={})

    assert build_notification_text(risk, language="ru") == "Сейчас высокий риск по воздуху/жаре. Ограничьте активность на улице."
    assert build_notification_text(risk, language="en") == "High air/heat risk now. Limit outdoor activity."
