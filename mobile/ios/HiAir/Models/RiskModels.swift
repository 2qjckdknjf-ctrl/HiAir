import Foundation

struct EnvironmentSnapshot: Codable {
    let temperatureC: Double
    let humidityPercent: Double?
    let aqi: Int?
    let pm25: Double?
    let ozone: Double?
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
    let ventilationWindows: [AirSafeWindow]?
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
    let humidity: Double?
    let aqi: Int?
    let pm25: Double?
    let pm10: Double?
    let ozone: Double?
    let uv: Double?
    let windSpeed: Double?
    let source: String
    let timestamp: String
    let timezone: String?

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
    let dataQuality: String?
    let freshness: String?
    let sources: [String]?
    let generatedAt: String?
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
    let generatedAt: String?
    let dataQuality: String?
    let freshness: String?
    let sources: [String]?
    let forecastHours: Int?
    let forecastAvailable: Bool?
    let missingMetrics: [String]?

    var isForecastAvailable: Bool {
        forecastAvailable ?? !hourlyRisk.isEmpty
    }
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

struct SymptomHistoryItem: Codable {
    let id: String
    let profileId: String
    let symptomType: String
    let intensity: Int
    let note: String?
    let loggedAt: String
}

struct SymptomHistoryResponse: Codable {
    let profileId: String
    let items: [SymptomHistoryItem]
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
    let refreshToken: String?
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "bearer"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(tokenType, forKey: .tokenType)
    }
}

struct UserProfile: Codable {
    let id: String
    let userId: String
    let personaType: String
    let sensitivityLevel: String
    let homeLat: Double
    let homeLon: Double
    let dateOfBirth: String?
    let ageYears: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case personaType = "persona_type"
        case sensitivityLevel = "sensitivity_level"
        case homeLat = "home_lat"
        case homeLon = "home_lon"
        case dateOfBirth = "date_of_birth"
        case ageYears = "age_years"
    }
}

struct ProfileCreatePayload: Codable {
    let personaType: String
    let sensitivityLevel: String
    let homeLat: Double
    let homeLon: Double
    let dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
        case personaType = "persona_type"
        case sensitivityLevel = "sensitivity_level"
        case homeLat = "home_lat"
        case homeLon = "home_lon"
        case dateOfBirth = "date_of_birth"
    }
}

struct ProfileUpdatePayload: Codable {
    let personaType: String?
    let sensitivityLevel: String?
    let homeLat: Double?
    let homeLon: Double?
    let dateOfBirth: String?

    enum CodingKeys: String, CodingKey {
        case personaType = "persona_type"
        case sensitivityLevel = "sensitivity_level"
        case homeLat = "home_lat"
        case homeLon = "home_lon"
        case dateOfBirth = "date_of_birth"
    }
}

struct SubscriptionPlan: Codable {
    let planId: String
    let name: String
    let billingCycle: String
    let priceUsd: Double?
    let trialDays: Int
    let iosProductId: String?
    let androidProductId: String?
    let isPremium: Bool?

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case name
        case billingCycle = "billing_cycle"
        case priceUsd = "price_usd"
        case trialDays = "trial_days"
        case iosProductId = "ios_product_id"
        case androidProductId = "android_product_id"
        case isPremium = "is_premium"
    }
}

struct UserEntitlementResponse: Codable {
    let userId: String
    let plan: String
    let isPremium: Bool
    let maxProfiles: Int
    let extendedForecastEnabled: Bool
    let customAlertsEnabled: Bool
    let exportReportsEnabled: Bool
    let advancedInsightsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case plan
        case isPremium = "is_premium"
        case maxProfiles = "max_profiles"
        case extendedForecastEnabled = "extended_forecast_enabled"
        case customAlertsEnabled = "custom_alerts_enabled"
        case exportReportsEnabled = "export_reports_enabled"
        case advancedInsightsEnabled = "advanced_insights_enabled"
    }
}

struct SubscriptionStatusResponse: Codable {
    let userId: String
    let planId: String?
    let status: String
    let startsAt: String?
    let currentPeriodEnd: String?
    let autoRenew: Bool
    let entitlement: UserEntitlementResponse?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case planId = "plan_id"
        case status
        case startsAt = "starts_at"
        case currentPeriodEnd = "current_period_end"
        case autoRenew = "auto_renew"
        case entitlement
    }
}

struct IosVerifyRequest: Codable {
    let signedTransaction: String
    let productId: String?

    enum CodingKeys: String, CodingKey {
        case signedTransaction = "signed_transaction"
        case productId = "product_id"
    }
}

struct RestoreSubscriptionRequest: Codable {
    let platform: String
    let iosSignedTransactions: [String]
    let androidPurchases: [AndroidPurchasePayload]

    enum CodingKeys: String, CodingKey {
        case platform
        case iosSignedTransactions = "ios_signed_transactions"
        case androidPurchases = "android_purchases"
    }
}

struct AndroidPurchasePayload: Codable {
    let productId: String
    let purchaseToken: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case purchaseToken = "purchase_token"
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

struct WearableConsentPayload: Codable {
    let platform: String
    let source: String
    let stepsEnabled: Bool
    let heartRateEnabled: Bool
    let restingHeartRateEnabled: Bool
    let hrvEnabled: Bool
    let sleepEnabled: Bool
    var activityEnabled: Bool? = nil
    var sleepStagesEnabled: Bool? = nil
    var respiratoryEnabled: Bool? = nil
    var temperatureEnabled: Bool? = nil
    var workoutsEnabled: Bool? = nil
    var fitnessEnabled: Bool? = nil
    var bodyMetricsEnabled: Bool? = nil
    var sensitiveMetricsEnabled: Bool? = nil
    let consentVersion: String
}

struct WearableDailySummaryPayload: Codable {
    let date: String
    let stepsTotal: Int?
    let heartRateAvg: Double?
    let heartRateMin: Double?
    let heartRateMax: Double?
    let restingHeartRateAvg: Double?
    let source: String
}

struct WearableHourlySummaryPayload: Codable {
    let hourStart: String
    let stepsTotal: Int?
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let source: String
}

struct WearableConsentResponse: Codable {
    let id: String
    let userId: String
    let platform: String
    let source: String
    let stepsEnabled: Bool
    let heartRateEnabled: Bool
    let restingHeartRateEnabled: Bool
    let isActive: Bool

    /// Used when HTTP 2xx succeeds but response schema drifts — local consent must still persist.
    static func acceptedStub(userId: String, platform: String, source: String) -> WearableConsentResponse {
        WearableConsentResponse(
            id: "local-accepted",
            userId: userId,
            platform: platform,
            source: source,
            stepsEnabled: true,
            heartRateEnabled: true,
            restingHeartRateEnabled: true,
            isActive: true
        )
    }
}

struct WearableDailySummaryResponse: Codable {
    let id: String
    let date: String
    let stepsTotal: Int?
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let restingHeartRateAvg: Double?
    let source: String
}

struct PersonalLoadSummary: Codable {
    let score: Int
    let level: String
    let explanations: [String]
    let reasonCodes: [String]
}

struct WearableTodayResponse: Codable {
    let consent: WearableConsentResponse?
    let dailySummary: WearableDailySummaryResponse?
    let personalLoad: PersonalLoadSummary?
}

struct WearableDataDeleteResponse: Codable {
    let deletedDaily: Int
    let deletedHourly: Int
    let consentRevoked: Bool
}

// MARK: - HiAir 1.2 Activity Best-Time

struct ActivityCatalogItem: Codable, Identifiable, Hashable {
    let activity: String
    let defaultDurationMinutes: Int
    let defaultIntensity: String
    let outdoor: Bool

    var id: String { activity }
}

struct ActivityCatalogResponse: Codable {
    let activities: [ActivityCatalogItem]
}

struct ActivityPlanRequest: Codable {
    let profileId: String
    let activity: String
    let durationMinutes: Int?
    let intensity: String?
    let earliestStart: String?
    let latestStart: String?
    let placeId: String?
}

struct ActivityHourAssessment: Codable {
    let hour: String
    let tier: String
    let score: Int
    let reasonCodes: [String]
}

struct ActivityWindow: Codable, Identifiable, Hashable {
    let tier: String
    let start: String
    let end: String
    let score: Int
    let reasonCodes: [String]
    let confidence: Double

    var id: String { "\(tier)-\(start)-\(end)" }
}

struct ActivityPlanResponse: Codable {
    let profileId: String
    let activity: String
    let intensity: String
    let durationMinutes: Int
    let timezone: String
    let forecastAvailable: Bool
    let dataQuality: String?
    let freshness: String?
    let sources: [String]?
    let missingMetrics: [String]?
    let generatedAt: String?
    let hourly: [ActivityHourAssessment]
    let windows: [ActivityWindow]
    let recommendedStart: String?
    let personalLoadScore: Int?
    let personalLoadLevel: String?
    let personalLoadReasonCodes: [String]?

    var isForecastAvailable: Bool {
        forecastAvailable
    }
}

// MARK: - HiAir 1.3 Multi-Hazard

struct HazardScore: Codable, Identifiable, Hashable {
    let hazard: String
    let level: String
    let score: Int
    let available: Bool
    let reasonCodes: [String]
    let unavailableReason: String?

    var id: String { hazard }
}

struct MultiHazardAssessment: Codable {
    let profileId: String
    let assessedAt: String
    let hazards: [HazardScore]
    let overallLevel: String
    let overallScore: Int
    let availableCount: Int
    let reasonCodes: [String]
}

struct HazardsResponse: Codable {
    let profileId: String
    let assessedAt: String
    let environmental: AirEnvironmentalInput
    let assessment: MultiHazardAssessment
    let dataQuality: String?
    let freshness: String?
    let sources: [String]?
    let generatedAt: String?
}

// MARK: - HiAir 1.5 Saved Places

struct SavedPlace: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let placeType: String
    let lat: Double
    let lon: Double
    let timezone: String?
    let createdAt: String?
}

struct SavedPlaceCreateRequest: Codable {
    let name: String
    let placeType: String
    let lat: Double
    let lon: Double
    let timezone: String?
}

struct SavedPlaceListResponse: Codable {
    let places: [SavedPlace]
}

// MARK: - HiAir 1.6 Personal Adaptation

struct PersonalBaseline: Codable, Identifiable, Hashable {
    let metric: String
    let window: String
    let value: Double?
    let sampleSize: Int
    let confidence: Double
    let available: Bool

    var id: String { "\(metric)-\(window)" }
}

struct ProtectedDaysSummary: Codable {
    let highRiskPeriodsAvoided: Int
    let workoutsMoved: Int
    let ventilationWindowsUsed: Int
    let poorAirExposureReduced: Int
    let available: Bool
}

struct PersonalAdaptationSnapshot: Codable {
    let profileId: String
    let generatedAt: String
    let baselines: [PersonalBaseline]
    let protectedDays: ProtectedDaysSummary
    let reasonCodes: [String]
}
