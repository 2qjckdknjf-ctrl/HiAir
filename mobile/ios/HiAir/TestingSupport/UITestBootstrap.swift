import Foundation

/// Launch-argument driven seed for Simulator UI tests. Never enables itself in production launches.
enum UITestBootstrap {
    static let uiTestingArgument = "-UITesting"
    static let mockAPIArgument = "-UITestMockAPI"
    static let skipOnboardingArgument = "-UITestSkipOnboarding"
    static let languageArgumentPrefix = "-UITestLanguage="

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var isMockAPIEnabled: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains(mockAPIArgument)
    }

    static var shouldSkipOnboarding: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains(skipOnboardingArgument)
    }

    static var forcedLanguage: String? {
        guard isUITesting else { return nil }
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(languageArgumentPrefix) })?
            .replacingOccurrences(of: languageArgumentPrefix, with: "")
    }

    static var isStoreShots: Bool {
        isUITesting && ProcessInfo.processInfo.environment["UITEST_STORE_SHOTS"] == "1"
    }

    static var shouldReportShotEnvironment: Bool {
        isStoreShots || ProcessInfo.processInfo.environment["HIAIR_REPORT_SHOT_ENV"] == "1"
    }

    static var requestedAccessibilitySize: String? {
        ProcessInfo.processInfo.environment["HIAIR_SHOT_ACCESSIBILITY"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_HIAIR_SHOT_ACCESSIBILITY"]
    }

    static var requestedReduceMotion: String? {
        ProcessInfo.processInfo.environment["HIAIR_SHOT_REDUCE_MOTION"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_HIAIR_SHOT_REDUCE_MOTION"]
    }

    static var requestedReduceTransparency: String? {
        ProcessInfo.processInfo.environment["HIAIR_SHOT_REDUCE_TRANSPARENCY"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_HIAIR_SHOT_REDUCE_TRANSPARENCY"]
    }

    /// Hide DEBUG-only operator chrome (API testing, AI observability) during any UITest run.
    /// Store shots and App Review device tests must match Release, not a debug Settings dump.
    static var hidesDebugOperatorChrome: Bool {
        isUITesting
    }

    static var disableAutoProfileBootstrap: Bool {
        isUITesting && ProcessInfo.processInfo.environment["UITEST_DISABLE_AUTO_PROFILE"] == "1"
    }

    /// Test-only: account-bound durable consent exists with server-inactive semantics.
    /// Requires `-UITesting`. Never active in production launches.
    static var seedWearableDurableInactive: Bool {
        isUITesting
            && ProcessInfo.processInfo.environment["UITEST_SEED_WEARABLE_DURABLE_INACTIVE"] == "1"
    }

    static func prepareBeforeAppLaunch() {
        guard isUITesting else { return }
        if isMockAPIEnabled {
            UITestMockAPIProtocol.reset()
            UITestMockAPIProtocol.isEnabled = true
            let env = ProcessInfo.processInfo.environment
            applyMatrixStateMocks(env)
            if let status = Int(env["UITEST_PROFILES_STATUS"] ?? ""), status != 200 {
                UITestMockAPIProtocol.reset(
                    listProfiles: .json(status, object: ["detail": "uitest status \(status)"]),
                    createProfile: .json(status, object: ["detail": "uitest status \(status)"])
                )
            }
            // Inactive-consent UI seed: durable marker + inactive server payload (no upload/delete).
            if env["UITEST_SEED_WEARABLE_DURABLE_INACTIVE"] == "1" {
                UITestMockAPIProtocol.setRoute(
                    method: "GET",
                    path: "/api/v1/wearables/today",
                    response: .json(
                        200,
                        object: [
                            "consent": [
                                "id": "uitest-inactive-consent",
                                "userId": env["UITEST_USER_ID"] ?? "uitest-user",
                                "platform": "ios",
                                "source": "apple_health",
                                "stepsEnabled": true,
                                "heartRateEnabled": true,
                                "restingHeartRateEnabled": true,
                                "isActive": false,
                            ],
                            "dailySummary": NSNull(),
                            "personalLoad": NSNull(),
                        ]
                    )
                )
            }
            if env["UITEST_STORE_SHOTS"] == "1" {
                installStoreScreenshotMocks()
            }
        }
    }

    private static func mockHourlyRisk() -> [[String: String]] {
        (0..<24).map { hour in
            let risk: String
            switch hour {
            case 7, 8, 9, 18, 19:
                risk = "low"
            case 12, 13, 14, 15:
                risk = "high"
            case 10, 11, 16, 17:
                risk = "moderate"
            default:
                risk = "low"
            }
            return [
                "hour": String(format: "2026-08-08T%02d:00:00Z", hour),
                "overallRisk": risk,
            ]
        }
    }

    /// Rich deterministic payloads so Simulator store screenshots show real product UI (not empty/error shells).
    private static func applyMatrixStateMocks(_ env: [String: String]) {
        guard let matrixState = env["UITEST_MATRIX_STATE"], !matrixState.isEmpty else { return }
        switch matrixState.lowercased() {
        case "loading":
            UITestMockAPIProtocol.responseDelayNanoseconds = 120_000_000_000
        case "error":
            UITestMockAPIProtocol.setRoute(
                method: "GET",
                path: "/api/air/current-risk",
                response: .json(503, object: ["detail": "uitest matrix error"])
            )
        case "offline":
            UITestMockAPIProtocol.failNextWithURLError = .notConnectedToInternet
            UITestMockAPIProtocol.failURLErrorPathSubstring = "/api/air/current-risk"
            UITestMockAPIProtocol.failErrorRemainingCount = 99
        default:
            break
        }
    }

    /// Rich deterministic payloads so Simulator store screenshots show real product UI (not empty/error shells).
    private static func installStoreScreenshotMocks() {
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/air/current-risk",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "assessedAt": "2026-08-08T10:00:00Z",
                    "environmental": [
                        "lat": 41.28,
                        "lon": 1.976,
                        "temperature": 27.0,
                        "feels_like": 28.0,
                        "humidity": 48.0,
                        "aqi": 52,
                        "pm25": 11.0,
                        "pm10": 18.0,
                        "ozone": 42.0,
                        "uv": 6.0,
                        "wind_speed": 3.5,
                        "source": "live",
                        "timestamp": "2026-08-08T10:00:00Z",
                        "timezone": "Europe/Madrid",
                    ],
                    "risk": [
                        "overallRisk": "moderate",
                        "heatRisk": "moderate",
                        "airRisk": "low",
                        "outdoorRisk": "moderate",
                        "indoorVentilationRisk": "low",
                        "safeWindows": [
                            [
                                "type": "morning",
                                "start": "2026-08-08T07:00:00Z",
                                "end": "2026-08-08T09:30:00Z",
                                "confidence": 0.86,
                            ],
                            [
                                "type": "evening",
                                "start": "2026-08-08T18:00:00Z",
                                "end": "2026-08-08T20:00:00Z",
                                "confidence": 0.8,
                            ],
                        ],
                        "recommendationFlags": ["hydrate", "shade"],
                        "reasonCodes": ["heat", "aqi"],
                    ],
                    "recommendation": [
                        "headline": "Plan outdoor time around cooler hours",
                        "summary": "Air is generally fine; heat rises mid-day. Prefer morning or evening walks.",
                        "actions": [
                            "Go outside before 10:00 or after 18:00",
                            "Carry water and seek shade at midday",
                            "Check AQI again if you feel sensitive",
                        ],
                    ],
                    "explanation": "Moderate outdoor risk mainly from heat. Air quality looks comfortable for most people.",
                    "explanationSource": "live",
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/air/day-plan",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "timezone": "Europe/Madrid",
                    "hourlyRisk": mockHourlyRisk(),
                    "safeWindows": [
                        [
                            "type": "outdoor",
                            "start": "2026-08-08T07:00:00Z",
                            "end": "2026-08-08T09:00:00Z",
                            "confidence": 0.86,
                        ],
                        [
                            "type": "ventilation",
                            "start": "2026-08-08T07:00:00Z",
                            "end": "2026-08-08T10:00:00Z",
                            "confidence": 0.8,
                        ],
                    ],
                    "ventilationWindows": [
                        [
                            "type": "ventilation",
                            "start": "2026-08-08T07:00:00Z",
                            "end": "2026-08-08T10:00:00Z",
                            "confidence": 0.8,
                        ],
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/planner/activities",
            response: .json(
                200,
                object: [
                    "activities": [
                        ["activity": "walking", "defaultDurationMinutes": 30, "defaultIntensity": "low", "outdoor": true],
                        ["activity": "running", "defaultDurationMinutes": 45, "defaultIntensity": "high", "outdoor": true],
                    ]
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "POST",
            path: "/api/planner/activity-plan",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "activity": "walking",
                    "intensity": "moderate",
                    "durationMinutes": 45,
                    "timezone": "Europe/Madrid",
                    "forecastAvailable": true,
                    "dataQuality": "complete",
                    "freshness": "live",
                    "sources": ["openmeteo"],
                    "generatedAt": "2026-08-08T10:00:00Z",
                    "hourly": [],
                    "windows": [
                        [
                            "tier": "best",
                            "start": "2026-08-08T07:00:00Z",
                            "end": "2026-08-08T09:00:00Z",
                            "score": 25,
                            "confidence": 0.86,
                            "reasonCodes": ["heat"],
                        ],
                        [
                            "tier": "best",
                            "start": "2026-08-08T18:00:00Z",
                            "end": "2026-08-08T20:00:00Z",
                            "score": 30,
                            "confidence": 0.8,
                            "reasonCodes": ["aqi"],
                        ],
                    ],
                    "recommendedStart": "2026-08-08T07:00:00Z",
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/insights/personal-patterns",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "windowDays": 30,
                    "generatedAt": "2026-08-08T10:00:00Z",
                    "items": [
                        [
                            "factorA": "heat",
                            "factorB": "fatigue",
                            "coefficient": 0.42,
                            "pValue": 0.08,
                            "sampleSize": 6,
                            "humanReadableText": "Warmer afternoons often line up with the days you logged fatigue.",
                        ]
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/v1/health/insights",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "generatedAt": "2026-08-08T10:00:00Z",
                    "today": [
                        "steps": 7421,
                        "sleepMinutes": 441,
                        "restingHeartRate": 68,
                    ],
                    "trends": [
                        [
                            "insightKey": "sleep-recovery",
                            "title": "Sleep and recovery",
                            "observation": "Sleep duration held near 7 hours across the last week.",
                            "recommendation": "Keep a consistent wind-down before midnight.",
                            "confidence": "medium",
                            "sampleSize": 6,
                            "windowDays": 7,
                        ],
                    ],
                    "associations": [
                        [
                            "insightKey": "heat-symptoms",
                            "title": "Heat and symptoms",
                            "observation": "Warmer afternoon hours align with the days you logged fatigue.",
                            "recommendation": "Shift outdoor time to the morning window.",
                            "confidence": "medium",
                            "sampleSize": 5,
                            "windowDays": 7,
                        ],
                    ],
                    "insufficientData": [],
                    "healthDataStatus": [
                        "lastSuccessAt": "2026-08-08T10:00:00Z",
                        "syncStatus": "ok",
                        "metricDays": 7,
                        "sleepDays": 5,
                        "consentActive": true,
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/v1/health/summary",
            response: .json(
                200,
                object: [
                    "localDate": "2026-08-08",
                    "timezone": "Europe/Madrid",
                    "metrics": [
                        [
                            "metricType": "heart_rate",
                            "unit": "bpm",
                            "valueAvg": 68,
                            "valueLatest": 68,
                            "sampleCount": 12,
                            "qualityState": "ok",
                        ],
                        [
                            "metricType": "steps",
                            "unit": "count",
                            "valueTotal": 7421,
                            "sampleCount": 1,
                            "qualityState": "ok",
                        ],
                        [
                            "metricType": "active_energy",
                            "unit": "kcal",
                            "valueTotal": 412,
                            "sampleCount": 1,
                            "qualityState": "ok",
                        ],
                    ],
                    "sleep": [
                        "localDate": "2026-08-08",
                        "totalMinutes": 441,
                        "qualityState": "ok",
                    ],
                    "dataDaysAvailable": 7,
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/v1/wearables/today",
            response: .json(
                200,
                object: [
                    "consent": [
                        "id": "uitest-consent",
                        "userId": "uitest-user",
                        "platform": "ios",
                        "source": "apple_health",
                        "stepsEnabled": true,
                        "heartRateEnabled": true,
                        "restingHeartRateEnabled": true,
                        "isActive": true,
                    ],
                    "dailySummary": NSNull(),
                    "personalLoad": [
                        "score": 72,
                        "level": "low",
                        "explanations": [
                            "Your body shows positive signs of recovery. Keep it up!",
                        ],
                        "reasonCodes": ["recovery"],
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/ai/reports/morning",
            response: .json(
                200,
                object: [
                    "kind": "morning",
                    "narrative": "A comfortable air day with rising heat after noon. Use the morning window for outdoor time.",
                    "source": "sample",
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/v1/health/symptoms/taxonomy",
            response: .json(
                200,
                object: [
                    "consentVersion": "health-intelligence-v1",
                    "safetyNotice": "Guidance, not diagnosis. Log how you feel so HiAir can find personal patterns.",
                    "count": 6,
                    "categories": [
                        [
                            "id": "checkin",
                            "label": "Check-in",
                            "symptoms": [
                                ["symptomType": "breathing", "label": "Breathing", "redFlag": false],
                                ["symptomType": "headache", "label": "Headache", "redFlag": false],
                                ["symptomType": "fatigue", "label": "Fatigue", "redFlag": false],
                                ["symptomType": "dizziness", "label": "Dizziness", "redFlag": false],
                                ["symptomType": "cough", "label": "Cough", "redFlag": false],
                                ["symptomType": "allergy", "label": "Allergy", "redFlag": false],
                            ],
                        ]
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/symptoms/history",
            response: .json(
                200,
                object: [
                    "profileId": "profile-uitest-1",
                    "items": [],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/subscriptions/me",
            response: .json(
                200,
                object: [
                    "user_id": "uitest-user",
                    "plan_id": NSNull(),
                    "status": "none",
                    "starts_at": NSNull(),
                    "current_period_end": NSNull(),
                    "auto_renew": false,
                    "entitlement": [
                        "user_id": "uitest-user",
                        "plan": "free",
                        "is_premium": false,
                        "max_profiles": 1,
                        "extended_forecast_enabled": false,
                        "custom_alerts_enabled": false,
                        "export_reports_enabled": false,
                        "advanced_insights_enabled": false,
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "POST",
            path: "/api/subscriptions/ios/verify",
            response: .json(
                200,
                object: [
                    "user_id": "uitest-user",
                    "plan_id": "monthly",
                    "status": "active",
                    "starts_at": "2026-08-20T00:00:00Z",
                    "current_period_end": "2026-09-20T00:00:00Z",
                    "auto_renew": true,
                    "entitlement": [
                        "user_id": "uitest-user",
                        "plan": "monthly",
                        "is_premium": true,
                        "max_profiles": 5,
                        "extended_forecast_enabled": true,
                        "custom_alerts_enabled": true,
                        "export_reports_enabled": true,
                        "advanced_insights_enabled": true,
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "POST",
            path: "/api/subscriptions/restore",
            response: .json(
                200,
                object: [
                    "user_id": "uitest-user",
                    "plan_id": "monthly",
                    "status": "active",
                    "starts_at": "2026-08-20T00:00:00Z",
                    "current_period_end": "2026-09-20T00:00:00Z",
                    "auto_renew": true,
                    "entitlement": [
                        "user_id": "uitest-user",
                        "plan": "monthly",
                        "is_premium": true,
                        "max_profiles": 5,
                        "extended_forecast_enabled": true,
                        "custom_alerts_enabled": true,
                        "export_reports_enabled": true,
                        "advanced_insights_enabled": true,
                    ],
                ]
            )
        )
        UITestMockAPIProtocol.setRoute(
            method: "GET",
            path: "/api/subscriptions/plans",
            response: .json(
                200,
                object: [
                    "plans": [
                        ["id": "monthly", "productId": "com.hiair.premium.monthly", "period": "month"],
                        ["id": "yearly", "productId": "com.hiair.premium.yearly", "period": "year"],
                    ]
                ]
            )
        )
    }

    @MainActor
    static func apply(to session: AppSession) {
        guard isUITesting else { return }

        if let language = forcedLanguage, !language.isEmpty {
            session.preferredLanguage = language
        }

        let env = ProcessInfo.processInfo.environment
        if env["UITEST_SEED_AUTH"] == "1" {
            session.userId = env["UITEST_USER_ID"] ?? "uitest-user"
            session.email = env["UITEST_EMAIL"] ?? "uitest@example.com"
            session.accessToken = env["UITEST_ACCESS_TOKEN"] ?? "uitest-access-token"
            session.refreshToken = env["UITEST_REFRESH_TOKEN"] ?? "uitest-refresh-token"
        } else {
            // Deterministic unsigned state for auth-screen UI tests.
            session.userId = ""
            session.email = ""
            session.accessToken = ""
            session.refreshToken = ""
            session.profileId = ""
        }

        if shouldSkipOnboarding {
            session.onboardingCompleted = true
        } else if isUITesting {
            session.onboardingCompleted = false
        }

        if let tabRaw = env["UITEST_SELECTED_TAB"], let tab = Int(tabRaw), (0...4).contains(tab) {
            session.selectedTab = tab
        }

        if env["UITEST_SEED_LOCATION"] == "1" {
            let lat = Double(env["UITEST_LAT"] ?? "41.2800") ?? 41.2800
            let lon = Double(env["UITEST_LON"] ?? "1.9760") ?? 1.9760
            session.latitude = lat
            session.longitude = lon
            session.locationSource = .device
            session.displayPlaceName = env["UITEST_PLACE_NAME"] ?? "Castelldefels"
        } else {
            session.latitude = 0
            session.longitude = 0
            session.locationSource = .unknown
            session.displayPlaceName = nil
        }

        if env["UITEST_CLEAR_PROFILE"] == "1" {
            session.profileId = ""
        }

        if let profileId = env["UITEST_PROFILE_ID"], !profileId.isEmpty {
            session.profileId = profileId
        }

        // TF167 harness: retain OS authorization markers without durable account consent,
        // and optionally leave a stale `.connected` presentation for demotion on refresh.
        if env["UITEST_SEED_WEARABLE_OS_AUTH_NO_CONSENT"] == "1", !session.userId.isEmpty {
            let hk = HealthKitService.shared
            hk.seedDurableConsentMarkersForTests(
                userId: session.userId,
                authorized: true,
                consented: false
            )
            hk.bindAccount(userId: session.userId)
            if env["UITEST_SEED_STALE_CONNECTED"] == "1" {
                hk.reportConnectionState(.connected)
            }
        }

        // Durable inactive: account-bound consent marker retained, active=false semantics.
        // Simulates prior OS authorization via UserDefaults markers — no real HealthKit store.
        if seedWearableDurableInactive, !session.userId.isEmpty {
            let hk = HealthKitService.shared
            hk.seedDurableConsentMarkersForTests(
                userId: session.userId,
                authorized: true,
                consented: true
            )
            hk.bindAccount(userId: session.userId)
            // Stale connected enum must not survive as account-connected UI when inactive.
            hk.reportConnectionState(.connected)
        }
    }
}
