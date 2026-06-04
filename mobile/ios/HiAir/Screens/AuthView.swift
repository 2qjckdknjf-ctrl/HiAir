import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loading = false
    @Published var statusText = "-"

    private let supabaseAuth = SupabaseAuthService.shared
    private let apiClient = APIClient.live()

    func signup(session: AppSession) async {
        await authenticate(session: session, mode: "signup")
    }

    func login(session: AppSession) async {
        await authenticate(session: session, mode: "login")
    }

    private func authenticate(session: AppSession, mode: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            statusText = session.l("auth.enter_email")
            return
        }
        guard password.count >= 12 else {
            statusText = session.l("auth.password_short")
            return
        }
        loading = true
        defer { loading = false }

        do {
            if let bridged = try await emailBridgeSession(
                email: normalizedEmail,
                password: password,
                signup: mode == "signup"
            ) {
                applyAuthSession(bridged, session: session)
                statusText = session.l("auth.ok")
                return
            }

            if mode == "signup" {
                switch try await supabaseAuth.signUp(email: normalizedEmail, password: password) {
                case .session(let authSession):
                    applyAuthSession(authSession, session: session)
                    statusText = session.l("auth.ok")
                case .emailConfirmationRequired(let confirmedEmail):
                    if let bridged = try await emailBridgeSession(
                        email: normalizedEmail,
                        password: password,
                        signup: true
                    ) {
                        applyAuthSession(bridged, session: session)
                        statusText = session.l("auth.ok")
                    } else {
                        session.authNotice = String(format: session.l("auth.confirm_email"), confirmedEmail)
                        statusText = session.l("auth.confirm_email_short")
                    }
                }
            } else {
                let authSession = try await supabaseAuth.signIn(email: normalizedEmail, password: password)
                applyAuthSession(authSession, session: session)
                statusText = session.l("auth.ok")
            }
        } catch is URLError {
            statusText = session.l("auth.backend_unreachable")
        } catch let apiError as APIError {
            statusText = apiErrorMessage(apiError, session: session)
        } catch let failure as SupabaseAuthFailure {
            statusText = failure.message
        } catch {
            statusText = session.l("auth.fail")
        }
    }

    private func emailBridgeSession(
        email: String,
        password: String,
        signup: Bool
    ) async throws -> SupabaseAuthSession? {
        do {
            let response = try await apiClient.supabaseEmailSession(
                email: email,
                password: password,
                signup: signup
            )
            guard let refresh = response.refreshToken, !refresh.isEmpty else { return nil }
            return SupabaseAuthSession(
                userId: response.userId,
                email: email,
                accessToken: response.accessToken,
                refreshToken: refresh
            )
        } catch let apiError as APIError {
            if case .server(let code) = apiError, code == 404 {
                return nil
            }
            if case .serverWithDetail(let code, _) = apiError, code == 404 {
                return nil
            }
            throw apiError
        }
    }

    private func apiErrorMessage(_ error: APIError, session: AppSession) -> String {
        switch error {
        case .serverWithDetail(let code, let detail) where !detail.isEmpty:
            if code == 429 {
                return session.l("auth.rate_limited")
            }
            return detail
        case .server(let code):
            if code == 429 {
                return session.l("auth.rate_limited")
            }
            if code >= 500 {
                return session.l("auth.bridge_unreachable")
            }
            return String(format: session.l("auth.server_error"), code)
        default:
            return session.l("auth.fail")
        }
    }

    private func applyAuthSession(_ authSession: SupabaseAuthSession, session: AppSession) {
        supabaseAuth.adoptSession(authSession)
        session.userId = authSession.userId
        session.email = authSession.email
        session.accessToken = authSession.accessToken
        session.refreshToken = authSession.refreshToken
        session.authNotice = ""
        Task {
            let hasProfile = await session.ensureProfileIdIfNeeded()
            if hasProfile {
                session.markChecklistItem("profile", done: true)
            }
        }
    }

    func signInWithApple(session: AppSession) async {
        loading = true
        defer { loading = false }
        do {
            let authSession = try await supabaseAuth.signInWithApple()
            applyAuthSession(authSession, session: session)
            statusText = session.l("auth.ok")
        } catch AppleSignInError.cancelled {
            statusText = session.l("auth.cancelled")
        } catch is AppleSignInError {
            statusText = session.l("auth.fail")
        } catch let failure as SupabaseAuthFailure {
            statusText = oauthFailureMessage(failure.message, provider: "Apple", session: session)
        } catch is URLError {
            statusText = session.l("auth.backend_unreachable")
        } catch {
            statusText = session.l("auth.fail")
        }
    }

    func signInWithGoogle(session: AppSession) async {
        loading = true
        defer { loading = false }
        do {
            try await supabaseAuth.signInWithGoogle()
            statusText = session.l("auth.oauth_continue")
        } catch let failure as SupabaseAuthFailure {
            statusText = oauthFailureMessage(failure.message, provider: "Google", session: session)
        } catch {
            statusText = session.l("auth.fail")
        }
    }

    private func oauthFailureMessage(_ message: String, provider: String, session: AppSession) -> String {
        let lowered = message.lowercased()
        if lowered.contains("provider is not enabled")
            || lowered.contains("could not be found")
            || lowered.contains("not enabled")
        {
            return String(format: session.l("auth.oauth_not_configured"), provider)
        }
        return message
    }
}

@MainActor
struct AuthView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        HiAirAdaptiveLayout { width, _ in
            ScrollView {
                VStack(spacing: HiAirSpacing.md) {
                    HiAirBrandHeader(
                        title: "HiAir",
                        subtitle: session.l("brand.tagline"),
                        showOrb: true,
                        orbSize: min(HiAirScreenMetrics.heroOrbSize(for: width), 120)
                    )
                    .padding(.top, HiAirSpacing.sm)

                    Text(session.l("auth.title"))
                        .font(HiAirTypography.titleMD)
                        .foregroundStyle(HiAirColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HiAirGlassCard {
                        VStack(spacing: 12) {
                            TextField(session.l("auth.email"), text: $viewModel.email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .hiAirInputSurface()
                                .foregroundStyle(HiAirV2Theme.primaryText)

                            SecureField(session.l("auth.password"), text: $viewModel.password)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .hiAirInputSurface()
                                .foregroundStyle(HiAirV2Theme.primaryText)
                        }
                    }

                    Button(viewModel.loading ? session.l("auth.signing_up") : session.l("auth.sign_up")) {
                        Task { await viewModel.signup(session: session) }
                    }
                    .buttonStyle(HiAirGradientButtonStyle())
                    .disabled(viewModel.loading)

                    Button(viewModel.loading ? session.l("auth.logging_in") : session.l("auth.log_in")) {
                        Task { await viewModel.login(session: session) }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)

                    Button("Sign in with Apple") {
                        Task { await viewModel.signInWithApple(session: session) }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)

                    Button("Sign in with Google") {
                        Task { await viewModel.signInWithGoogle(session: session) }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .disabled(viewModel.loading)

                    if !session.authNotice.isEmpty {
                        Text(session.authNotice)
                            .font(HiAirTypography.caption)
                            .foregroundStyle(HiAirColors.Feedback.errorSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(viewModel.statusText)
                        .font(HiAirTypography.caption)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .hiAirContentWidth(for: width)
                .hiAirScreenPadding(for: width)
                .padding(.bottom, HiAirSpacing.xl)
            }
        }
        .hiAirPageBackground()
    }
}
