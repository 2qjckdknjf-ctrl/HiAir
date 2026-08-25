from enum import Enum

from pydantic import BaseModel, Field


class PersonaType(str, Enum):
    ADULT = "adult"
    CHILD = "child"
    ELDERLY = "elderly"
    ASTHMA = "asthma"
    ALLERGY = "allergy"
    RUNNER = "runner"
    WORKER = "worker"


class SymptomInput(BaseModel):
    cough: bool = False
    wheeze: bool = False
    headache: bool = False
    fatigue: bool = False
    sleep_quality: int = Field(default=3, ge=1, le=5)


class EnvironmentSnapshot(BaseModel):
    temperature_c: float
    humidity_percent: float = Field(ge=0, le=100)
    aqi: int | None = Field(default=None, ge=0)
    pm25: float | None = Field(default=None, ge=0)
    ozone: float | None = Field(default=None, ge=0)
    no2: float | None = None
    source: str = "mock"
    pm10: float | None = None
    uv: float | None = None
    wind_speed: float | None = None
    feels_like: float | None = None
    timezone: str | None = None
    pollen_grains_m3: float | None = None
    wildfire_pm10: float | None = None
    # Estimated outdoor WBGT from meteo (never instrument WBGT).
    wbgt_c: float | None = None
    wbgt_estimated: bool = False
    shortwave_wm2: float | None = None


class RiskEstimateRequest(BaseModel):
    persona: PersonaType
    symptoms: SymptomInput = SymptomInput()
    environment: EnvironmentSnapshot
    profile_id: str | None = None


class RiskEstimateResponse(BaseModel):
    score: int = Field(ge=0, le=100)
    level: str
    recommendations: list[str]
    components: dict[str, int]


class SymptomLogCreateRequest(BaseModel):
    profile_id: str
    symptom: SymptomInput


class SymptomLogResponse(BaseModel):
    id: str
    profile_id: str
    timestamp_utc: str
    symptom: SymptomInput


class RiskHistoryItem(BaseModel):
    id: str
    profile_id: str
    score_value: int
    risk_level: str
    recommendations: list[str]
    created_at: str
