package com.hiair.models

data class EnvironmentSnapshot(
    val temperature_c: Double,
    val humidity_percent: Double,
    val aqi: Int,
    val pm25: Double,
    val ozone: Double,
    val source: String
)

data class SymptomInput(
    val cough: Boolean = false,
    val wheeze: Boolean = false,
    val headache: Boolean = false,
    val fatigue: Boolean = false,
    val sleep_quality: Int = 3
)

data class RiskEstimateRequest(
    val persona: String,
    val symptoms: SymptomInput,
    val environment: EnvironmentSnapshot,
    val profile_id: String? = null
)

data class RiskEstimateResponse(
    val score: Int,
    val level: String,
    val recommendations: List<String>,
    val components: Map<String, Int>
)

data class DashboardOverviewResponse(
    val profile_id: String?,
    val environment: EnvironmentSnapshot,
    val risk_score: Int,
    val risk_level: String,
    val recommendations: List<String>,
    val daily_summary: String,
    val daily_actions: List<String>,
    val should_notify: Boolean,
    val notification_text: String
)

data class SymptomLogRequest(
    val profile_id: String,
    val symptom: SymptomInput
)

data class SymptomLogResponse(
    val id: String,
    val profile_id: String,
    val timestamp_utc: String,
    val symptom: SymptomInput
)

data class PlannerHourlyItem(
    val hour_iso: String,
    val score: Int,
    val level: String
)

data class SafeWindow(
    val start_hour_iso: String,
    val end_hour_iso: String
)

data class DailyPlannerResponse(
    val persona: String,
    val base_lat: Double,
    val base_lon: Double,
    val hourly: List<PlannerHourlyItem>,
    val safe_windows: List<SafeWindow>
)

data class UserSettingsResponse(
    val user_id: String,
    val push_alerts_enabled: Boolean,
    val alert_threshold: String,
    val default_persona: String,
    val quiet_hours_start: Int,
    val quiet_hours_end: Int,
    val profile_based_alerting: Boolean,
    val preferred_language: String
)

data class UserSettingsUpdateRequest(
    val push_alerts_enabled: Boolean,
    val alert_threshold: String,
    val default_persona: String,
    val quiet_hours_start: Int,
    val quiet_hours_end: Int,
    val profile_based_alerting: Boolean,
    val preferred_language: String
)

data class AirSafeWindow(
    val type: String,
    val start: String,
    val end: String,
    val confidence: Double
)

data class AirRiskAssessment(
    val overallRisk: String,
    val heatRisk: String,
    val airRisk: String,
    val outdoorRisk: String,
    val indoorVentilationRisk: String,
    val safeWindows: List<AirSafeWindow>,
    val recommendationFlags: List<String>,
    val reasonCodes: List<String>
)

data class AirRecommendationCard(
    val headline: String,
    val summary: String,
    val actions: List<String>
)

data class AirCurrentRiskResponse(
    val profileId: String,
    val assessedAt: String,
    val risk: AirRiskAssessment,
    val recommendation: AirRecommendationCard,
    val explanation: String,
    val explanationSource: String
)

data class AirDayPlanResponse(
    val profileId: String,
    val timezone: String,
    val hourlyRisk: List<Map<String, String>>,
    val safeWindows: List<AirSafeWindow>,
    val ventilationWindows: List<AirSafeWindow>
)
