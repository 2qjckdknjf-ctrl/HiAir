from pydantic import BaseModel


class ThresholdBand(BaseModel):
    metric: str
    bands: list[str]


class RiskThresholdsResponse(BaseModel):
    version: str
    references: list[str]
    thresholds: list[ThresholdBand]
