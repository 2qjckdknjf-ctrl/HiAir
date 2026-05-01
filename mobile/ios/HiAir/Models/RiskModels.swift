import Foundation

struct EnvironmentSnapshot: Codable {
    let temperatureC: Double
    let humidityPercent: Double
    let aqi: Int
    let pm25: Double
    let ozone: Double
    let source: String

    enum CodingKeys: String, CodingKey {
        case temperatureC = "temperature_c"
        case humidityPercent = "humidity_percent"
        case aqi
        case pm25
        case ozone
        case source
    }
}

struct SymptomInput: Codable {
    let cough: Bool
    let wheeze: Bool
    let headache: Bool
    let fatigue: Bool
    let sleepQuality: Int

    enum CodingKeys: String, CodingKey {
        case cough
        case wheeze
        case headache
        case fatigue
        case sleepQuality = "sleep_quality"
    }
}

struct RiskEstimateRequest: Codable {
    let persona: String
    let symptoms: SymptomInput
    let environment: EnvironmentSnapshot
    let profileId: String?

    enum CodingKeys: String, CodingKey {
        case persona
        case symptoms
        case environment
        case profileId = "profile_id"
    }
}

struct RiskEstimateResponse: Codable {
    let score: Int
    let level: String
    let recommendations: [String]
    let components: [String: Int]
}

struct DashboardOverviewResponse: Codable {
    let profileId: String?
    let environment: EnvironmentSnapshot
    let riskScore: Int
    let riskLevel: String
    let recommendations: [String]
    let dailySummary: String
    let dailyActions: [String]
    let shouldNotify: Bool
    let notificationText: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case environment
        case riskScore = "risk_score"
        case riskLevel = "risk_level"
        case recommendations
        case dailySummary = "daily_summary"
        case dailyActions = "daily_actions"
        case shouldNotify = "should_notify"
        case notificationText = "notification_text"
    }
}

struct SymptomLogRequest: Codable {
    let profileId: String
    let symptom: SymptomInput

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case symptom
    }
}

struct SymptomLogResponse: Codable {
    let id: String
    let profileId: String
    let timestampUtc: String
    let symptom: SymptomInput

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case timestampUtc = "timestamp_utc"
        case symptom
    }
}

struct PlannerHourlyItem: Codable {
    let hourIso: String
    let score: Int
    let level: String

    enum CodingKeys: String, CodingKey {
        case hourIso = "hour_iso"
        case score
        case level
    }
}

struct SafeWindow: Codable {
    let startHourIso: String
    let endHourIso: String

    enum CodingKeys: String, CodingKey {
        case startHourIso = "start_hour_iso"
        case endHourIso = "end_hour_iso"
    }
}

struct DailyPlannerResponse: Codable {
    let persona: String
    let baseLat: Double
    let baseLon: Double
    let hourly: [PlannerHourlyItem]
    let safeWindows: [SafeWindow]

    enum CodingKeys: String, CodingKey {
        case persona
        case baseLat = "base_lat"
        case baseLon = "base_lon"
        case hourly
        case safeWindows = "safe_windows"
    }
}

struct UserSettingsResponse: Codable {
    let userId: String
    let pushAlertsEnabled: Bool
    let alertThreshold: String
    let defaultPersona: String
    let quietHoursStart: Int
    let quietHoursEnd: Int
    let profileBasedAlerting: Bool
    let preferredLanguage: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pushAlertsEnabled = "push_alerts_enabled"
        case alertThreshold = "alert_threshold"
        case defaultPersona = "default_persona"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case profileBasedAlerting = "profile_based_alerting"
        case preferredLanguage = "preferred_language"
    }
}

struct UserSettingsUpdateRequest: Codable {
    let pushAlertsEnabled: Bool
    let alertThreshold: String
    let defaultPersona: String
    let quietHoursStart: Int
    let quietHoursEnd: Int
    let profileBasedAlerting: Bool
    let preferredLanguage: String

    enum CodingKeys: String, CodingKey {
        case pushAlertsEnabled = "push_alerts_enabled"
        case alertThreshold = "alert_threshold"
        case defaultPersona = "default_persona"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case profileBasedAlerting = "profile_based_alerting"
        case preferredLanguage = "preferred_language"
    }
}

struct AirSafeWindow: Codable {
    let type: String
    let start: String
    let end: String
    let confidence: Double
}

struct AirRiskAssessment: Codable {
    let overallRisk: String
    let heatRisk: String
    let airRisk: String
    let outdoorRisk: String
    let indoorVentilationRisk: String
    let safeWindows: [AirSafeWindow]
    let recommendationFlags: [String]
    let reasonCodes: [String]
}

struct AirRecommendationCard: Codable {
    let headline: String
    let summary: String
    let actions: [String]
}

struct AirEnvironmentalInput: Codable {
    let lat: Double
    let lon: Double
    let temperature: Double
    let feelsLike: Double
    let humidity: Double
    let aqi: Int
    let pm25: Double
    let pm10: Double
    let ozone: Double
    let uv: Double
    let windSpeed: Double
    let source: String
    let timestamp: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case temperature
        case feelsLike = "feels_like"
        case humidity
        case aqi
        case pm25
        case pm10
        case ozone
        case uv
        case windSpeed = "wind_speed"
        case source
        case timestamp
        case timezone
    }
}

struct AirCurrentRiskResponse: Codable {
    let profileId: String
    let assessedAt: String
    let environmental: AirEnvironmentalInput
    let risk: AirRiskAssessment
    let recommendation: AirRecommendationCard
    let explanation: String
    let explanationSource: String
}

struct AirHourlyRiskPoint: Codable {
    let hour: String
    let overallRisk: String
}

struct AirDayPlanResponse: Codable {
    let profileId: String
    let timezone: String
    let hourlyRisk: [AirHourlyRiskPoint]
    let safeWindows: [AirSafeWindow]
    let ventilationWindows: [AirSafeWindow]
}

struct PersonalPatternInsight: Codable {
    let factorA: String
    let factorB: String
    let coefficient: Double
    let pValue: Double
    let sampleSize: Int
    let humanReadableText: String
}

struct PersonalPatternsResponse: Codable {
    let profileId: String
    let windowDays: Int
    let generatedAt: String
    let items: [PersonalPatternInsight]
}

struct BriefingScheduleResponse: Codable {
    let userId: String
    let localTime: String
    let timezone: String
    let enabled: Bool
    let lastSentAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case localTime = "local_time"
        case timezone
        case enabled
        case lastSentAt = "last_sent_at"
    }
}

struct BriefingScheduleUpdateRequest: Codable {
    let localTime: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case localTime = "local_time"
        case enabled
    }
}

struct AirSymptomCreateRequest: Codable {
    let profileId: String
    let symptomType: String
    let intensity: Int
    let note: String?

    enum CodingKeys: String, CodingKey {
        case profileId
        case symptomType
        case intensity
        case note
    }
}

struct AIApiSummaryResponse: Codable {
    let total: Int
    let fallbackCount: Int
    let guardrailBlockCount: Int
    let timeoutCount: Int?
    let networkCount: Int?
    let serverCount: Int?
    let hours: Int?
    let fallbackRatePct: Double?
    let guardrailBlockRatePct: Double?
    let timeoutRatePct: Double?
    let networkRatePct: Double?
    let serverRatePct: Double?

    enum CodingKeys: String, CodingKey {
        case total
        case fallbackCount = "fallback_count"
        case guardrailBlockCount = "guardrail_block_count"
        case timeoutCount = "timeout_count"
        case networkCount = "network_count"
        case serverCount = "server_count"
        case hours
        case fallbackRatePct = "fallback_rate_pct"
        case guardrailBlockRatePct = "guardrail_block_rate_pct"
        case timeoutRatePct = "timeout_rate_pct"
        case networkRatePct = "network_rate_pct"
        case serverRatePct = "server_rate_pct"
    }
}

struct AIDetailedTrendPoint: Codable {
    let hour: String
    let total: Int
    let fallbackCount: Int
    let guardrailBlockCount: Int
    let timeoutCount: Int?
    let networkCount: Int?
    let serverCount: Int?

    enum CodingKeys: String, CodingKey {
        case hour
        case total
        case fallbackCount = "fallback_count"
        case guardrailBlockCount = "guardrail_block_count"
        case timeoutCount = "timeout_count"
        case networkCount = "network_count"
        case serverCount = "server_count"
    }
}

struct AIBreakdownByPromptVersion: Codable {
    let promptVersion: String
    let total: Int
    let fallbackCount: Int
    let guardrailBlockCount: Int

    enum CodingKeys: String, CodingKey {
        case promptVersion = "prompt_version"
        case total
        case fallbackCount = "fallback_count"
        case guardrailBlockCount = "guardrail_block_count"
    }
}

struct AIBreakdownByModelName: Codable {
    let modelName: String
    let total: Int
    let fallbackCount: Int
    let guardrailBlockCount: Int

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case total
        case fallbackCount = "fallback_count"
        case guardrailBlockCount = "guardrail_block_count"
    }
}

struct AIDetailedBreakdown: Codable {
    let byPromptVersion: [AIBreakdownByPromptVersion]
    let byModelName: [AIBreakdownByModelName]
    let byErrorType: [AIBreakdownByErrorType]

    enum CodingKeys: String, CodingKey {
        case byPromptVersion = "by_prompt_version"
        case byModelName = "by_model_name"
        case byErrorType = "by_error_type"
    }
}

struct AIBreakdownByErrorType: Codable {
    let errorType: String
    let total: Int

    enum CodingKeys: String, CodingKey {
        case errorType = "error_type"
        case total
    }
}

struct AIApiSummaryDetailedResponse: Codable {
    let summary: AIApiSummaryResponse
    let trend: [AIDetailedTrendPoint]
    let breakdown: AIDetailedBreakdown
}

struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let userId: String
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct SubscriptionPlan: Codable {
    let planId: String
    let name: String
    let billingCycle: String
    let priceUsd: Double
    let trialDays: Int

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case name
        case billingCycle = "billing_cycle"
        case priceUsd = "price_usd"
        case trialDays = "trial_days"
    }
}

struct SubscriptionStatusResponse: Codable {
    let userId: String
    let planId: String?
    let status: String
    let startsAt: String?
    let currentPeriodEnd: String?
    let autoRenew: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case planId = "plan_id"
        case status
        case startsAt = "starts_at"
        case currentPeriodEnd = "current_period_end"
        case autoRenew = "auto_renew"
    }
}

struct ActivateSubscriptionRequest: Codable {
    let planId: String
    let useTrial: Bool

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case useTrial = "use_trial"
    }
}
