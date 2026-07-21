import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case server(statusCode: Int)
    case serverWithDetail(statusCode: Int, detail: String)
}

struct SupabaseAuthSession: Sendable {
    let userId: String
    let email: String
    let accessToken: String
    let refreshToken: String
}

enum SupabaseSignUpResult: Sendable {
    case session(SupabaseAuthSession)
    case emailConfirmationRequired(email: String)
}

struct SupabaseAuthFailure: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

@MainActor
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()
    static let sessionDidChange = Notification.Name("hiair.supabase.session.did.change")
    static let sessionOAuthFailed = Notification.Name("hiair.supabase.session.oauth.failed")

    private let urlSession: URLSession = .shared
    private let supabaseURL: URL?
    private let anonKey: String
    private let redirectURI: String
    private var pendingOAuthCodeVerifier: String?
    private let appleSignIn = AppleSignInCoordinator()

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment
        let rawURL = env["SUPABASE_URL"] ?? (info["SUPABASE_URL"] as? String) ?? ""
        anonKey = env["SUPABASE_ANON_KEY"] ?? (info["SUPABASE_ANON_KEY"] as? String) ?? ""
        redirectURI = env["HIAIR_AUTH_REDIRECT_URI"] ?? (info["HIAIR_AUTH_REDIRECT_URI"] as? String) ?? "hiair://auth/callback"
        supabaseURL = URL(string: rawURL)
    }

    func restoreSessionIfNeeded() async throws -> SupabaseAuthSession? {
        return nil
    }

    func signUp(email: String, password: String) async throws -> SupabaseSignUpResult {
        let payload = ["email": email, "password": password]
        let data = try await request(
            method: "POST",
            path: "/auth/v1/signup",
            query: nil,
            body: payload
        )
        let result = try parseSignUpResponse(from: data, fallbackEmail: email)
        if case .session(let session) = result {
            notifySessionChanged(session)
        }
        return result
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let payload = ["email": email, "password": password]
        let data = try await request(
            method: "POST",
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: payload
        )
        let session = try parseSession(from: data, fallbackEmail: email)
        notifySessionChanged(session)
        return session
    }

    /// Native Sign in with Apple (TestFlight/App Store). Requires Apple provider enabled in Supabase.
    func signInWithApple() async throws -> SupabaseAuthSession {
        let (credential, rawNonce) = try await appleSignIn.signIn()
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty
        else {
            throw AppleSignInError.missingIdentityToken
        }
        let data = try await request(
            method: "POST",
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "id_token")],
            body: [
                "provider": "apple",
                "id_token": idToken,
                "nonce": rawNonce,
            ]
        )
        let session = try parseSession(from: data, fallbackEmail: credential.email ?? "")
        notifySessionChanged(session)
        return session
    }

    func signInWithGoogle() async throws {
        try await openOAuth(provider: "google")
    }

    func refreshSession() async throws -> SupabaseAuthSession? {
        guard let state = APIClient.getAuthState(), !state.refreshToken.isEmpty else {
            return nil
        }
        let payload = ["refresh_token": state.refreshToken]
        let data = try await request(
            method: "POST",
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: payload
        )
        let session = try parseSession(from: data, fallbackEmail: "")
        notifySessionChanged(session)
        return session
    }

    func signOut() async {
        guard let state = APIClient.getAuthState() else {
            NotificationCenter.default.post(name: Self.sessionDidChange, object: nil)
            return
        }
        do {
            _ = try await request(
                method: "POST",
                path: "/auth/v1/logout",
                query: nil,
                body: [:],
                bearerToken: state.accessToken
            )
        } catch {
            // Best effort signout.
        }
        NotificationCenter.default.post(name: Self.sessionDidChange, object: nil)
    }

    func handleCallbackURL(_ url: URL) async -> Bool {
        guard url.scheme?.lowercased() == "hiair", url.host?.lowercased() == "auth" else {
            return false
        }

        let params = Self.parseAuthURLParams(url)
        if let error = params["error"] ?? params["error_code"] {
            let description = params["error_description"] ?? params["msg"] ?? error
            notifyOAuthFailed(description)
            return false
        }

        if let code = params["code"], !code.isEmpty {
            return await exchangeOAuthCode(code)
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"]
        else {
            notifyOAuthFailed("Missing OAuth tokens in callback.")
            return false
        }
        return finalizeOAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: params["user_id"] ?? params["sub"],
            email: params["email"] ?? ""
        )
    }

    private func exchangeOAuthCode(_ code: String) async -> Bool {
        guard let verifier = pendingOAuthCodeVerifier, !verifier.isEmpty else {
            notifyOAuthFailed("OAuth state expired. Try again.")
            return false
        }
        pendingOAuthCodeVerifier = nil
        do {
            let data = try await request(
                method: "POST",
                path: "/auth/v1/token",
                query: [URLQueryItem(name: "grant_type", value: "pkce")],
                body: [
                    "auth_code": code,
                    "code_verifier": verifier,
                ]
            )
            let session = try parseSession(from: data, fallbackEmail: "")
            notifySessionChanged(session)
            return true
        } catch let failure as SupabaseAuthFailure {
            notifyOAuthFailed(failure.message)
            return false
        } catch {
            notifyOAuthFailed("OAuth sign-in failed.")
            return false
        }
    }

    private func finalizeOAuthSession(
        accessToken: String,
        refreshToken: String,
        userId: String?,
        email: String
    ) -> Bool {
        let resolvedUserId = userId ?? userIdFromAccessToken(accessToken) ?? ""
        guard !resolvedUserId.isEmpty else {
            notifyOAuthFailed("OAuth user id missing.")
            return false
        }
        let session = SupabaseAuthSession(
            userId: resolvedUserId,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
        notifySessionChanged(session)
        return true
    }

    private func openOAuth(provider: String) async throws {
        guard let base = supabaseURL else {
            throw APIError.invalidURL
        }
        guard !anonKey.isEmpty else {
            throw SupabaseAuthFailure(message: "Supabase anon key is not configured in the app.")
        }
        let verifier = Self.randomURLSafeString(length: 64)
        let challenge = Self.pkceChallenge(for: verifier)
        pendingOAuthCodeVerifier = verifier

        var components = URLComponents(url: base.appending(path: "/auth/v1/authorize"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectURI),
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        guard let target = components?.url else {
            throw APIError.invalidURL
        }

        await MainActor.run {
            UIApplication.shared.open(target)
        }
    }

    private static func parseAuthURLParams(_ url: URL) -> [String: String] {
        var pairs: [String: String] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems?.forEach { item in
                if let value = item.value {
                    pairs[item.name] = value
                }
            }
        }
        if let fragment = url.fragment, !fragment.isEmpty {
            for item in fragment.split(separator: "&") {
                let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                pairs[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return pairs
    }

    private static func randomURLSafeString(length: Int) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~")
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private static func pkceChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func notifyOAuthFailed(_ message: String) {
        NotificationCenter.default.post(name: Self.sessionOAuthFailed, object: message)
    }

    private func request(
        method: String,
        path: String,
        query: [URLQueryItem]?,
        body: [String: String],
        bearerToken: String? = nil
    ) async throws -> Data {
        guard let base = supabaseURL else {
            throw APIError.invalidURL
        }
        var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = extractSupabaseErrorMessage(from: data)
            if let detail, !detail.isEmpty {
                throw SupabaseAuthFailure(message: detail)
            }
            throw APIError.server(statusCode: http.statusCode)
        }
        return data
    }

    private func extractSupabaseErrorMessage(from data: Data) -> String? {
        guard
            !data.isEmpty,
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        if let msg = payload["msg"] as? String, !msg.isEmpty {
            return msg
        }
        if let description = payload["error_description"] as? String, !description.isEmpty {
            return description
        }
        if let error = payload["error"] as? String, !error.isEmpty {
            return error
        }
        return nil
    }

    private func parseSignUpResponse(from data: Data, fallbackEmail: String) throws -> SupabaseSignUpResult {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }
        if payload["access_token"] != nil {
            return .session(try parseSession(from: data, fallbackEmail: fallbackEmail))
        }
        let email = (payload["email"] as? String) ?? fallbackEmail
        if payload["confirmation_sent_at"] != nil {
            guard !email.isEmpty else {
                throw APIError.invalidResponse
            }
            return .emailConfirmationRequired(email: email)
        }
        if let user = payload["user"] as? [String: Any],
           user["confirmation_sent_at"] != nil {
            let confirmedEmail = (user["email"] as? String) ?? email
            return .emailConfirmationRequired(email: confirmedEmail)
        }
        throw APIError.invalidResponse
    }

    private func parseSession(from data: Data, fallbackEmail: String) throws -> SupabaseAuthSession {
        guard
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let accessToken = payload["access_token"] as? String,
            let refreshToken = payload["refresh_token"] as? String
        else {
            throw APIError.invalidResponse
        }
        let user = payload["user"] as? [String: Any]
        let userId = (payload["user_id"] as? String)
            ?? (user?["id"] as? String)
            ?? ""
        let email = (user?["email"] as? String) ?? fallbackEmail
        guard !userId.isEmpty else {
            throw APIError.invalidResponse
        }
        return SupabaseAuthSession(
            userId: userId,
            email: email,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    private func userIdFromAccessToken(_ accessToken: String) -> String? {
        let parts = accessToken.split(separator: ".")
        guard parts.count >= 2 else {
            return nil
        }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        guard
            let data = Data(base64Encoded: base64),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = payload["sub"] as? String,
            !sub.isEmpty
        else {
            return nil
        }
        return sub
    }

    func adoptSession(_ session: SupabaseAuthSession) {
        notifySessionChanged(session)
    }

    private func notifySessionChanged(_ session: SupabaseAuthSession) {
        NotificationCenter.default.post(name: Self.sessionDidChange, object: session)
    }
}

final class APIClient {
    struct AuthState {
        let userId: String
        let accessToken: String
        let refreshToken: String
    }

    private static let authStateLock = NSLock()
    private static var authState: AuthState?
    private static var authInvalidatedHandler: (() -> Void)?

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configuredURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    static func live(session: URLSession? = nil) -> APIClient {
        APIClient(
            baseURL: resolveBaseURL(),
            session: session ?? configuredURLSession()
        )
    }

    static func setAuthState(_ state: AuthState?) {
        authStateLock.lock()
        defer { authStateLock.unlock() }
        authState = state
    }

    static func setAuthInvalidatedHandler(_ handler: (() -> Void)?) {
        authStateLock.lock()
        defer { authStateLock.unlock() }
        authInvalidatedHandler = handler
    }

    static func getAuthState() -> AuthState? {
        authStateLock.lock()
        defer { authStateLock.unlock() }
        return authState
    }

    private static func clearAuthStateAndNotify() {
        authStateLock.lock()
        authState = nil
        let handler = authInvalidatedHandler
        authStateLock.unlock()
        handler?()
    }

    private static func resolveBaseURL() -> URL {
        #if DEBUG
        let defaultBaseURL = "http://127.0.0.1:8000"
        #else
        let defaultBaseURL = "https://api.hiair.io"
        #endif
        let fromEnv = ProcessInfo.processInfo.environment["HIAIR_API_BASE_URL"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let fromEnv,
           !fromEnv.isEmpty,
           let url = validatedBaseURL(fromEnv) {
            return url
        }

        let fromPlist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        if let fromPlist,
           !fromPlist.isEmpty,
           let url = validatedBaseURL(fromPlist) {
            return url
        }

        return URL(string: defaultBaseURL)!
    }

    private static func validatedBaseURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw) else {
            return nil
        }
        if url.scheme?.lowercased() == "https" {
            return url
        }
        #if DEBUG
        return url
        #else
        return nil
        #endif
    }

    private func applyAuthHeaders(
        to request: inout URLRequest,
        accessToken: String? = nil,
        userId: String? = nil
    ) {
        if let state = Self.getAuthState(), !state.accessToken.isEmpty {
            if let userId, !userId.isEmpty, userId != state.userId {
                // fall through to explicit token for mismatched session.
            } else {
                request.setValue("Bearer \(state.accessToken)", forHTTPHeaderField: "Authorization")
                return
            }
        }
        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            return
        }
        _ = userId
    }

    private func sendRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }

    private func sendRequestWithAutoRefresh(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, httpResponse) = try await sendRequest(request)
        guard httpResponse.statusCode == 401 else {
            return (data, httpResponse)
        }
        let refreshed = try await refreshAccessToken()
        guard refreshed else {
            Self.clearAuthStateAndNotify()
            return (data, httpResponse)
        }
        var retriedRequest = request
        if let state = Self.getAuthState(), !state.accessToken.isEmpty {
            retriedRequest.setValue("Bearer \(state.accessToken)", forHTTPHeaderField: "Authorization")
        }
        return try await sendRequest(retriedRequest)
    }

    private func refreshAccessToken() async throws -> Bool {
        guard let state = Self.getAuthState(),
              !state.refreshToken.isEmpty
        else {
            return false
        }
        guard let refreshed = try await SupabaseAuthService.shared.refreshSession() else {
            Self.clearAuthStateAndNotify()
            return false
        }
        let nextState = AuthState(
            userId: refreshed.userId,
            accessToken: refreshed.accessToken,
            refreshToken: refreshed.refreshToken.isEmpty ? state.refreshToken : refreshed.refreshToken
        )
        Self.setAuthState(nextState)
        return true
    }

    func signup(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "/api/auth/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthRequest(email: email, password: password))
        return try await executeAuthRequest(request)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let url = baseURL.appending(path: "/api/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthRequest(email: email, password: password))
        return try await executeAuthRequest(request)
    }

    /// Confirmed Supabase session via backend service role (TestFlight email unblock).
    func supabaseEmailSession(email: String, password: String, signup: Bool) async throws -> AuthResponse {
        let path = signup ? "/api/auth/supabase/signup" : "/api/auth/supabase/session"
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthRequest(email: email, password: password))
        return try await executeAuthRequest(request)
    }

    private func executeAuthRequest(_ request: URLRequest) async throws -> AuthResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let detail = extractErrorDetail(from: data), !detail.isEmpty {
                throw APIError.serverWithDetail(statusCode: httpResponse.statusCode, detail: detail)
            }
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func listProfiles(userId: String, accessToken: String? = nil) async throws -> [UserProfile] {
        let url = baseURL.appending(path: "/api/profiles")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode([UserProfile].self, from: data)
    }

    func createProfile(
        userId: String,
        payload: ProfileCreatePayload,
        accessToken: String? = nil
    ) async throws -> UserProfile {
        let url = baseURL.appending(path: "/api/profiles")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func updateProfile(
        userId: String,
        profileId: String,
        payload: ProfileUpdatePayload,
        accessToken: String? = nil
    ) async throws -> UserProfile {
        let url = baseURL.appending(path: "/api/profiles/\(profileId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            if let detail = extractErrorDetail(from: data), !detail.isEmpty {
                throw APIError.serverWithDetail(statusCode: httpResponse.statusCode, detail: detail)
            }
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    private func extractErrorDetail(from data: Data) -> String? {
        guard !data.isEmpty,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = payload["detail"] as? String else {
            return nil
        }
        return detail.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(AirDayPlanResponse.self, from: data)
    }

    func fetchPersonalPatterns(
        profileId: String,
        userId: String,
        accessToken: String? = nil,
        windowDays: Int = 30,
        language: String = "ru"
    ) async throws -> PersonalPatternsResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/insights/personal-patterns"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "window_days", value: String(windowDays)),
            URLQueryItem(name: "language", value: language),
        ]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(PersonalPatternsResponse.self, from: data)
    }

    func fetchSymptomHistory(
        profileId: String,
        userId: String,
        accessToken: String? = nil
    ) async throws -> SymptomHistoryResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/symptoms/history"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "profileId", value: profileId)]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SymptomHistoryResponse.self, from: data)
    }

    func fetchBriefingSchedule(
        userId: String,
        accessToken: String? = nil
    ) async throws -> BriefingScheduleResponse {
        let url = baseURL.appending(path: "/api/briefings/schedule")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(BriefingScheduleResponse.self, from: data)
    }

    func updateBriefingSchedule(
        userId: String,
        payload: BriefingScheduleUpdateRequest,
        accessToken: String? = nil
    ) async throws -> BriefingScheduleResponse {
        let url = baseURL.appending(path: "/api/briefings/schedule")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(BriefingScheduleResponse.self, from: data)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(UserSettingsResponse.self, from: data)
    }

    func fetchPrivacyExport(userId: String, accessToken: String? = nil) async throws -> [String: Any] {
        let url = baseURL.appending(path: "/api/privacy/export")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let payload = raw as? [String: Any] else {
            throw APIError.invalidResponse
        }
        return payload
    }

    func deleteAccount(userId: String, accessToken: String? = nil) async throws {
        let url = baseURL.appending(path: "/api/privacy/delete-account")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(["confirmation": "DELETE"])

        let (_, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (_, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (_, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
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

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }

    func verifyIosSubscription(
        userId: String,
        signedTransaction: String,
        productId: String?,
        accessToken: String? = nil
    ) async throws -> SubscriptionStatusResponse {
        let url = baseURL.appending(path: "/api/subscriptions/ios/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(
            IosVerifyRequest(signedTransaction: signedTransaction, productId: productId)
        )

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw subscriptionAPIError(statusCode: httpResponse.statusCode, data: data)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }

    func restoreSubscriptions(
        userId: String,
        platform: String,
        iosSignedTransactions: [String],
        accessToken: String? = nil
    ) async throws -> SubscriptionStatusResponse {
        let url = baseURL.appending(path: "/api/subscriptions/restore")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(
            RestoreSubscriptionRequest(
                platform: platform,
                iosSignedTransactions: iosSignedTransactions,
                androidPurchases: []
            )
        )

        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw subscriptionAPIError(statusCode: httpResponse.statusCode, data: data)
        }
        return try JSONDecoder().decode(SubscriptionStatusResponse.self, from: data)
    }

    private func subscriptionAPIError(statusCode: Int, data: Data) -> APIError {
        if let detail = extractErrorDetail(from: data), !detail.isEmpty {
            return .serverWithDetail(statusCode: statusCode, detail: detail)
        }
        return .server(statusCode: statusCode)
    }

    func saveWearableConsent(
        userId: String,
        accessToken: String? = nil,
        payload: WearableConsentPayload
    ) async throws -> WearableConsentResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/consent"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(WearableConsentResponse.self, from: data)
    }

    func revokeWearableConsent(userId: String, accessToken: String? = nil) async throws -> WearableConsentResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/consent"))
        request.httpMethod = "DELETE"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(WearableConsentResponse.self, from: data)
    }

    func uploadWearableDailySummary(
        userId: String,
        accessToken: String? = nil,
        payload: WearableDailySummaryPayload
    ) async throws -> WearableDailySummaryResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/daily-summary"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(WearableDailySummaryResponse.self, from: data)
    }

    func uploadWearableHourlySummary(
        userId: String,
        accessToken: String? = nil,
        payload: WearableHourlySummaryPayload
    ) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/hourly-summary"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
    }

    func fetchWearableToday(userId: String, accessToken: String? = nil) async throws -> WearableTodayResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/today"))
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(WearableTodayResponse.self, from: data)
    }

    func deleteWearableData(userId: String, accessToken: String? = nil) async throws -> WearableDataDeleteResponse {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/wearables/data"))
        request.httpMethod = "DELETE"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(WearableDataDeleteResponse.self, from: data)
    }

    func syncHealthData(
        userId: String,
        accessToken: String? = nil,
        payload: HealthSyncPayload
    ) async throws -> HealthSyncResponseDTO {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/health/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = payload.idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(HealthSyncResponseDTO.self, from: data)
    }

    func deleteHealthData(userId: String, accessToken: String? = nil) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/health/data"))
        request.httpMethod = "DELETE"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (_, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
    }

    func fetchHealthInsightsBundle(
        profileId: String,
        userId: String,
        accessToken: String? = nil,
        windowDays: Int = 30,
        language: String = "ru"
    ) async throws -> HealthInsightsBundleDTO {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/health/insights"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "profile_id", value: profileId),
            URLQueryItem(name: "window_days", value: String(windowDays)),
            URLQueryItem(name: "language", value: language),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(HealthInsightsBundleDTO.self, from: data)
    }

    func fetchHealthSummary(
        userId: String,
        accessToken: String? = nil,
        localDate: String? = nil
    ) async throws -> HealthSummaryResponseDTO {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/health/summary"),
            resolvingAgainstBaseURL: false
        )!
        if let localDate, !localDate.isEmpty {
            components.queryItems = [URLQueryItem(name: "local_date", value: localDate)]
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(HealthSummaryResponseDTO.self, from: data)
    }

    func fetchSymptomTaxonomy(language: String = "ru") async throws -> SymptomTaxonomyDTO {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/health/symptoms/taxonomy"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "language", value: language)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let (data, httpResponse) = try await session.data(for: request)
        guard let http = httpResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.server(statusCode: (httpResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return try JSONDecoder().decode(SymptomTaxonomyDTO.self, from: data)
    }

    func createComprehensiveSymptom(
        _ payload: ComprehensiveSymptomPayload,
        userId: String,
        accessToken: String? = nil,
        language: String = "ru"
    ) async throws -> ComprehensiveSymptomResponseDTO {
        var components = URLComponents(
            url: baseURL.appending(path: "/api/v1/health/symptoms"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "language", value: language)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeaders(to: &request, accessToken: accessToken, userId: userId)
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, httpResponse) = try await sendRequestWithAutoRefresh(request)
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.server(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(ComprehensiveSymptomResponseDTO.self, from: data)
    }
}

// MARK: - Native Sign in with Apple

enum AppleSignInError: LocalizedError {
    case missingIdentityToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple Sign In did not return an identity token."
        case .cancelled:
            return "Apple Sign In was cancelled."
        }
    }
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<(ASAuthorizationAppleIDCredential, String), Error>?
    private var currentNonce = ""

    func signIn() async throws -> (credential: ASAuthorizationAppleIDCredential, rawNonce: String) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(ASAuthorizationAppleIDCredential, String), Error>) in
            self.continuation = continuation
            currentNonce = Self.randomNonceString()
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = Self.sha256(currentNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset.randomElement()!)
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }
        guard credential.identityToken != nil else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: (credential, currentNonce))
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AppleSignInError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return keyWindow ?? ASPresentationAnchor()
    }
}
