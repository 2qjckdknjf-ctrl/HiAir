import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case server(statusCode: Int)
}

final class APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func live(session: URLSession = .shared) -> APIClient {
        APIClient(baseURL: resolveBaseURL(), session: session)
    }

    private static func resolveBaseURL() -> URL {
        let defaultBaseURL = "http://127.0.0.1:8000"
        let fromEnv = ProcessInfo.processInfo.environment["HIAIR_API_BASE_URL"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let fromEnv, !fromEnv.isEmpty, let url = URL(string: fromEnv) {
            return url
        }

        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        if let fromPlist, !fromPlist.isEmpty, let url = URL(string: fromPlist) {
            return url
        }

        return URL(string: defaultBaseURL)!
    }

    private func applyAuthHeaders(
        to request: inout URLRequest,
        accessToken: String? = nil,
        userId: String? = nil
    ) {
        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return
        }
        _ = userId
    }

    func signup(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "/api/auth/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthRequest(email: email, password: password))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "/api/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthRequest(email: email, password: password))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func fetchMockEnvironment(lat: Double, lon: Double) async throws -> EnvironmentSnapshot {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/environment/snapshot"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "source", value: "mock"),
        ]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(EnvironmentSnapshot.self, from: data)
    }

    func estimateRisk(_ payload: RiskEstimateRequest) async throws -> RiskEstimateResponse {
        let url = baseURL.appending(path: "/api/risk/estimate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(RiskEstimateResponse.self, from: data)
    }

    func fetchDashboardOverview(
        userId: String,
        accessToken: String? = nil,
        profileId: String? = nil,
        persona: String = "adult",
        lat: Double = 41.39,
        lon: Double = 2.17
    ) async throws -> DashboardOverviewResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/dashboard/overview"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "persona", value: persona),
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
        ]
        if let profileId {
            queryItems.append(URLQueryItem(name: "profile_id", value: profileId))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(DashboardOverviewResponse.self, from: data)
    }

    func fetchCurrentRisk(
        profileId: String,
        userId: String,
        accessToken: String? = nil
    ) async throws -> AirCurrentRiskResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/air/current-risk"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "profileId", value: profileId)]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AirCurrentRiskResponse.self, from: data)
    }

    func fetchAirDayPlan(
        profileId: String,
        userId: String,
        accessToken: String? = nil
    ) async throws -> AirDayPlanResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/air/day-plan"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "profileId", value: profileId)]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AirDayPlanResponse.self, from: data)
    }

    func logSymptom(
        _ payload: SymptomLogRequest,
        userId: String,
        accessToken: String? = nil
    ) async throws -> SymptomLogResponse {
        let url = baseURL.appending(path: "/api/symptoms/log")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SymptomLogResponse.self, from: data)
    }

    func fetchDailyPlanner(
        persona: String = "adult",
        lat: Double = 41.39,
        lon: Double = 2.17,
        hours: Int = 12
    ) async throws -> DailyPlannerResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/planner/daily"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "persona", value: persona),
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "hours", value: String(hours)),
        ]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(DailyPlannerResponse.self, from: data)
    }

    func fetchUserSettings(userId: String, accessToken: String? = nil) async throws -> UserSettingsResponse {
        let url = baseURL.appending(path: "/api/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UserSettingsResponse.self, from: data)
    }

    func updateUserSettings(
        userId: String,
        payload: UserSettingsUpdateRequest,
        accessToken: String? = nil
    ) async throws -> UserSettingsResponse {
        let url = baseURL.appending(path: "/api/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UserSettingsResponse.self, from: data)
    }

    func createQuickSymptom(
        _ payload: AirSymptomCreateRequest,
        userId: String,
        accessToken: String? = nil
    ) async throws {
        let url = baseURL.appending(path: "/api/symptoms")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
    }

    func fetchAISummary(hours: Int = 24) async throws -> AIApiSummaryResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/observability/ai-summary"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "hours", value: String(hours))]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AIApiSummaryResponse.self, from: data)
    }

    func fetchAISummaryDetailed(hours: Int = 24) async throws -> AIApiSummaryDetailedResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/observability/ai-summary-detailed"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "hours", value: String(hours))]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AIApiSummaryDetailedResponse.self, from: data)
    }

    func registerDeviceToken(
        userId: String,
        platform: String,
        deviceToken: String,
        profileId: String? = nil,
        accessToken: String? = nil
    ) async throws {
        let url = baseURL.appending(path: "/api/notifications/device-token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        struct Payload: Codable {
            let platform: String
            let deviceToken: String
            let profileId: String?

            enum CodingKeys: String, CodingKey {
                case platform
                case deviceToken = "device_token"
                case profileId = "profile_id"
            }
        }
        request.httpBody = try JSONEncoder().encode(
            Payload(platform: platform, deviceToken: deviceToken, profileId: profileId)
        )

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
    }

    func fetchSubscriptionPlans() async throws -> [SubscriptionPlan] {
        let url = baseURL.appending(path: "/api/subscriptions/plans")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode([SubscriptionPlan].self, from: data)
    }

    func fetchMySubscription(userId: String, accessToken: String? = nil) async throws -> SubscriptionStatusResponse {
        let url = baseURL.appending(path: "/api/subscriptions/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }

    func activateSubscription(
        userId: String,
        planId: String,
        useTrial: Bool = true,
        accessToken: String? = nil
    ) async throws -> SubscriptionStatusResponse {
        let url = baseURL.appending(path: "/api/subscriptions/activate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(
            ActivateSubscriptionRequest(planId: planId, useTrial: useTrial)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }

    func cancelSubscription(
        userId: String,
        accessToken: String? = nil
    ) async throws -> SubscriptionStatusResponse {
        let url = baseURL.appending(path: "/api/subscriptions/cancel")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }
}
