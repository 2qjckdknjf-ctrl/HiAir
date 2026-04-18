from fastapi import APIRouter

from app.models.validation import HistoricalValidationResponse
from app.services.risk_validation_service import run_historical_validation

router = APIRouter(prefix="/validation", tags=["validation"])


@router.get("/risk/historical", response_model=HistoricalValidationResponse)
def validate_historical_risk() -> HistoricalValidationResponse:
    return run_historical_validation()
