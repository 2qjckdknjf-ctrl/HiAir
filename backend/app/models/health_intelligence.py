from datetime import date, datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.wearable import WearablePlatform, WearableSource
from app.services.health_metrics import (
    QUALITY_STATES,
    expected_unit,
    is_known_metric,
    is_sensitive,
)
from app.services.symptom_taxonomy import is_known_symptom, is_red_flag


class QualityState(str, Enum):
    OK = "ok"
    PARTIAL = "partial"
    NO_RECORDS = "no_records"
    PERMISSION_UNKNOWN = "permission_unknown"
    PERMISSION_DENIED = "permission_denied"
    SOURCE_UNAVAILABLE = "source_unavailable"
    STALE = "stale"
    SYNC_ERROR = "sync_error"
    UNSUPPORTED = "unsupported"


class MetricSummaryItem(BaseModel):
    metricType: str
    valueAvg: float | None = None
    valueMin: float | None = None
    valueMax: float | None = None
    valueLatest: float | None = None
    valueTotal: float | None = None
    unit: str
    sampleCount: int = Field(default=0, ge=0, le=1_000_000)
    qualityState: QualityState = QualityState.OK
    hrvMethod: str | None = None
    sourceDeviceClass: str | None = Field(default=None, max_length=64)
    periodStart: datetime | None = None
    periodEnd: datetime | None = None

    @field_validator("metricType")
    @classmethod
    def validate_metric(cls, value: str) -> str:
        if not is_known_metric(value):
            raise ValueError(f"Unknown metricType: {value}")
        return value

    @model_validator(mode="after")
    def validate_unit_and_hrv(self) -> "MetricSummaryItem":
        expected = expected_unit(self.metricType)
        if expected and self.unit != expected:
            raise ValueError(f"Invalid unit for {self.metricType}: expected {expected}")
        if self.metricType == "hrv_sdnn" and self.hrvMethod not in (None, "sdnn"):
            raise ValueError("hrv_sdnn requires hrvMethod=sdnn")
        if self.metricType == "hrv_rmssd" and self.hrvMethod not in (None, "rmssd"):
            raise ValueError("hrv_rmssd requires hrvMethod=rmssd")
        if self.metricType.startswith("hrv_") and self.hrvMethod is None:
            self.hrvMethod = "sdnn" if self.metricType == "hrv_sdnn" else "rmssd"
        has_value = any(
            v is not None
            for v in (self.valueAvg, self.valueMin, self.valueMax, self.valueLatest, self.valueTotal)
        )
        if not has_value and self.qualityState == QualityState.OK:
            self.qualityState = QualityState.NO_RECORDS
        return self


class SleepSummaryItem(BaseModel):
    localDate: date
    totalMinutes: int | None = Field(default=None, ge=0, le=1440)
    inBedMinutes: int | None = Field(default=None, ge=0, le=1440)
    awakeMinutes: int | None = Field(default=None, ge=0, le=1440)
    coreLightMinutes: int | None = Field(default=None, ge=0, le=1440)
    deepMinutes: int | None = Field(default=None, ge=0, le=1440)
    remMinutes: int | None = Field(default=None, ge=0, le=1440)
    sleepStart: datetime | None = None
    sleepEnd: datetime | None = None
    qualityState: QualityState = QualityState.OK


class HealthSyncRequest(BaseModel):
    profileId: str | None = None
    localDate: date
    timezone: str = Field(default="UTC", min_length=1, max_length=64)
    platform: WearablePlatform
    source: WearableSource
    clientSyncVersion: str = Field(default="health-intelligence-v1", max_length=64)
    idempotencyKey: str | None = Field(default=None, max_length=128)
    metrics: list[MetricSummaryItem] = Field(default_factory=list, max_length=64)
    sleep: SleepSummaryItem | None = None
    cursorMetadata: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def limit_sensitive(self) -> "HealthSyncRequest":
        sensitive = [m for m in self.metrics if is_sensitive(m.metricType)]
        if len(sensitive) > 8:
            raise ValueError("Too many sensitive metrics in one sync")
        return self


class HealthSyncResponse(BaseModel):
    acceptedMetrics: int
    rejectedMetrics: list[str] = Field(default_factory=list)
    sleepAccepted: bool = False
    syncStatus: str
    lastSuccessAt: datetime | None = None


class HealthAvailabilityItem(BaseModel):
    metricType: str
    category: str
    qualityState: QualityState
    lastSyncedAt: datetime | None = None
    unit: str | None = None
    latestValue: float | None = None


class HealthAvailabilityResponse(BaseModel):
    platform: WearablePlatform | None = None
    source: WearableSource | None = None
    lastSuccessAt: datetime | None = None
    syncStatus: str | None = None
    items: list[HealthAvailabilityItem] = Field(default_factory=list)


class HealthSummaryMetric(BaseModel):
    metricType: str
    unit: str
    valueAvg: float | None = None
    valueMin: float | None = None
    valueMax: float | None = None
    valueLatest: float | None = None
    valueTotal: float | None = None
    sampleCount: int = 0
    qualityState: str
    hrvMethod: str | None = None
    trend7d: float | None = None
    baseline30d: float | None = None
    deviationFromBaseline: float | None = None


class HealthSummaryResponse(BaseModel):
    localDate: date
    timezone: str
    metrics: list[HealthSummaryMetric]
    sleep: SleepSummaryItem | None = None
    dataDaysAvailable: int = 0


class HealthTimelinePoint(BaseModel):
    localDate: date
    environment: dict[str, float | None] = Field(default_factory=dict)
    health: dict[str, float | None] = Field(default_factory=dict)
    symptoms: list[dict[str, Any]] = Field(default_factory=list)
    riskScore: int | None = None
    riskLevel: str | None = None
    completeness: dict[str, bool] = Field(default_factory=dict)


class HealthTimelineResponse(BaseModel):
    profileId: str
    windowDays: int
    points: list[HealthTimelinePoint]


class HealthDataDeleteResponse(BaseModel):
    deletedMetrics: int
    deletedSleep: int
    deletedLegacyDaily: int
    deletedLegacyHourly: int
    consentRevoked: bool


class ComprehensiveSymptomCreateRequest(BaseModel):
    profileId: str
    symptomType: str
    severity: int = Field(ge=1, le=5)
    onsetAt: datetime | None = None
    durationMinutes: int | None = Field(default=None, ge=0, le=10080)
    ongoing: bool = False
    frequency: str | None = Field(default=None, max_length=64)
    bodyContext: str | None = Field(default=None, max_length=128)
    suspectedTrigger: str | None = Field(default=None, max_length=128)
    activityAtOnset: str | None = Field(default=None, max_length=64)
    locationContext: str | None = Field(default=None, max_length=32)
    hydrationState: str | None = Field(default=None, max_length=32)
    medicationTaken: bool | None = None
    note: str | None = Field(default=None, max_length=500)
    timezone: str | None = Field(default=None, max_length=64)
    customLabel: str | None = Field(default=None, max_length=80)

    @field_validator("symptomType")
    @classmethod
    def validate_type(cls, value: str) -> str:
        if not is_known_symptom(value):
            raise ValueError(f"Unknown symptomType: {value}")
        return value


class ComprehensiveSymptomResponse(BaseModel):
    id: str
    profileId: str
    symptomType: str
    category: str | None
    severity: int
    onsetAt: datetime | None
    durationMinutes: int | None
    ongoing: bool
    note: str | None
    redFlag: bool
    safetyNotice: str | None
    loggedAt: datetime


class CustomSymptomCreateRequest(BaseModel):
    profileId: str
    label: str = Field(min_length=1, max_length=80)
    category: str = Field(default="custom", max_length=64)
    iconKey: str | None = Field(default=None, max_length=32)


class CustomSymptomResponse(BaseModel):
    id: str
    symptomType: str
    label: str
    category: str
    iconKey: str | None
    isHidden: bool


class InsightCard(BaseModel):
    insightKey: str
    title: str
    observation: str
    recommendation: str | None = None
    confidence: str
    sampleSize: int
    windowDays: int
    supportingFactors: list[str] = Field(default_factory=list)
    limitations: list[str] = Field(default_factory=list)
    whyShown: str | None = None
    chart: dict[str, Any] | None = None


class HealthInsightsBundleResponse(BaseModel):
    profileId: str
    generatedAt: datetime
    today: dict[str, Any]
    trends: list[InsightCard]
    associations: list[InsightCard]
    insufficientData: list[dict[str, Any]]
    healthDataStatus: dict[str, Any]


def symptom_is_red_flag(symptom_type: str) -> bool:
    return is_red_flag(symptom_type)


def quality_state_ok(value: str) -> bool:
    return value in QUALITY_STATES
