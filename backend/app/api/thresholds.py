from fastapi import APIRouter

from app.models.thresholds import RiskThresholdsResponse, ThresholdBand

router = APIRouter(prefix="/risk", tags=["risk"])


@router.get("/thresholds", response_model=RiskThresholdsResponse)
def risk_thresholds() -> RiskThresholdsResponse:
    return RiskThresholdsResponse(
        version="v1-rule-based",
        references=[
            "WHO AQG 2021 (air quality guidance)",
            "CDC heat stress public guidance",
            "Project conservative safety thresholds",
        ],
        thresholds=[
            ThresholdBand(
                metric="temperature_c",
                bands=["<29: low contribution", "29-32: medium", "33-37: high", ">=38: very high"],
            ),
            ThresholdBand(
                metric="aqi",
                bands=["0-50: low", "51-100: medium", "101-150: high", "151-200: very high", ">=201: severe"],
            ),
            ThresholdBand(
                metric="pm25",
                bands=["<15: low", "15-34: medium", "35-54: high", ">=55: very high"],
            ),
            ThresholdBand(
                metric="ozone",
                bands=["<70: low", "70-89: medium", "90-119: high", ">=120: very high"],
            ),
            ThresholdBand(
                metric="risk_level_score",
                bands=["0-34: low", "35-59: medium", "60-79: high", "80-100: very high"],
            ),
        ],
    )
