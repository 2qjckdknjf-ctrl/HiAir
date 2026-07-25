import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loading = false
    @Published var statusText = ""
    @Published var statusIsError = false

    private let supabaseAuth = SupabaseAuthService.shared
    private let apiClient = APIClient.live()

    func resetForDisplay() {
        loading = false
        if statusText == "-" {
            statusText = ""
        }
    }

    func signup(session: AppSession) async {
        await authenticate(session: session, mode: "signup")
    }

    func login(session: AppSession) async {
        await authenticate(session: session, mode: "login")
    }

    private func authenticate(session: AppSession, mode: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            showError(session.l("auth.enter_email"), session: session)
            return
        }
        guard password.count >= 12 else {
            showError(session.l("auth.password_short"), session: session)
            return
        }

        loading = true
        statusIsError = false
        statusText = session.l("auth.working")
        defer { loading = false }

        do {
            let authSession = try await resolveEmailSession(
                email: normalizedEmail,
                password: password,
                signup: mode == "signup",
                session: session
            )
            completeSignIn(authSession, session: session)
        } catch is URLError {
            showError(session.l("auth.backend_unreachable"), session: session)
        } catch let apiError as APIError {
            showError(apiErrorMessage(apiError, session: session), session: session)
        } catch let failure as SupabaseAuthFailure {
            showError(failure.message, session: session)
        } catch AuthFlowError.confirmationRequired {
            showError(session.l("auth.confirm_email_short"), session: session)
        } catch {
            showError(session.l("auth.fail"), session: session)
        }
    }

    private func resolveEmailSession(
        email: String,
        password: String,
        signup: Bool,
        session: AppSession
    ) async throws -> SupabaseAuthSession {
        if let bridged = try await emailBridgeSession(email: email, password: password, signup: signup) {
            return bridged
        }

        if signup {
            switch try await supabaseAuth.signUp(email: email, password: password) {
            case .session(let authSession):
                return authSession
            case .emailConfirmationRequired(let confirmedEmail):
                // Never fall back to bridge auto-confirm — that would bypass email proof.
                session.authNotice = String(format: session.l("auth.confirm_email"), confirmedEmail)
                throw AuthFlowError.confirmationRequired
            }
        }

        return try await supabaseAuth.signIn(email: email, password: password)
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
            guard let refresh = response.refreshToken, !refresh.isEmpty else {
                return nil
            }
            guard !response.userId.isEmpty, !response.accessToken.isEmpty else {
                return nil
            }
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
            if case .serverWithDetail(let code, let detail) = apiError {
                if code == 404 {
                    return nil
                }
                if signup && code == 403 && detail.lowercased().contains("confirm") {
                    throw AuthFlowError.confirmationRequired
                }
            }
            throw apiError
        }
    }

    private func completeSignIn(_ authSession: SupabaseAuthSession, session: AppSession) {
        session.installAuthSession(authSession)
        supabaseAuth.adoptSession(authSession)
        session.authNotice = ""
        statusIsError = false
        statusText = session.l("auth.ok")
        Task {
            _ = await session.ensureProfileIdIfNeeded()
            await session.refreshEntitlement()
        }
    }

    private func showError(_ message: String, session: AppSession) {
        statusIsError = true
        statusText = message
        session.authNotice = message
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
        case .invalidResponse:
            return session.l("auth.bad_response")
        default:
            return session.l("auth.fail")
        }
    }

    func signInWithApple(session: AppSession) async {
        loading = true
        statusIsError = false
        statusText = session.l("auth.working")
        defer { loading = false }
        do {
            let authSession = try await supabaseAuth.signInWithApple()
            completeSignIn(authSession, session: session)
        } catch AppleSignInError.cancelled {
            statusIsError = false
            statusText = session.l("auth.cancelled")
        } catch is AppleSignInError {
            showError(session.l("auth.fail"), session: session)
        } catch let failure as SupabaseAuthFailure {
            showError(oauthFailureMessage(failure.message, provider: "Apple", session: session), session: session)
        } catch is URLError {
            showError(session.l("auth.backend_unreachable"), session: session)
        } catch {
            showError(session.l("auth.fail"), session: session)
        }
    }

    func signInWithGoogle(session: AppSession) async {
        loading = true
        statusIsError = false
        statusText = session.l("auth.working")
        defer { loading = false }
        do {
            try await supabaseAuth.signInWithGoogle()
            statusIsError = false
            statusText = session.l("auth.oauth_continue")
        } catch let failure as SupabaseAuthFailure {
            showError(oauthFailureMessage(failure.message, provider: "Google", session: session), session: session)
        } catch {
            showError(session.l("auth.fail"), session: session)
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

private enum AuthFlowError: Error {
    case confirmationRequired
}

@MainActor
struct AuthView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        HiAirAdaptiveLayout { width, _ in
            ZStack {
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
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .hiAirInputSurface()
                                    .foregroundStyle(HiAirV2Theme.primaryText)

                                SecureField(session.l("auth.password"), text: $viewModel.password)
                                    .textContentType(.password)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .hiAirInputSurface()
                                    .foregroundStyle(HiAirV2Theme.primaryText)
                            }
                        }

                        Button(viewModel.loading ? session.l("auth.signing_up") : session.l("auth.sign_up")) {
                            Task { @MainActor in
                                await viewModel.signup(session: session)
                            }
                        }
                        .buttonStyle(HiAirGradientButtonStyle())
                        .disabled(viewModel.loading)

                        Button(viewModel.loading ? session.l("auth.logging_in") : session.l("auth.log_in")) {
                            Task { @MainActor in
                                await viewModel.login(session: session)
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .disabled(viewModel.loading)

                        Button(session.l("auth.sign_in_apple")) {
                            Task { @MainActor in
                                await viewModel.signInWithApple(session: session)
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .disabled(viewModel.loading)

                        Button(session.l("auth.sign_in_google")) {
                            Task { @MainActor in
                                await viewModel.signInWithGoogle(session: session)
                            }
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                        .disabled(viewModel.loading)

                        if !viewModel.statusText.isEmpty {
                            Text(viewModel.statusText)
                                .font(HiAirTypography.bodyMD)
                                .foregroundStyle(
                                    viewModel.statusIsError
                                        ? HiAirColors.Feedback.errorSoft
                                        : HiAirV2Theme.primaryText
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: HiAirRadius.md)
                                        .fill(
                                            viewModel.statusIsError
                                                ? HiAirColors.Feedback.errorSoft.opacity(0.12)
                                                : HiAirColors.Cta.gradientStart.opacity(0.12)
                                        )
                                )
                        }
                    }
                    .hiAirContentWidth(for: width)
                    .hiAirScreenPadding(for: width)
                    .padding(.bottom, HiAirSpacing.xl)
                }

                if viewModel.loading {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    VStack(spacing: HiAirSpacing.sm) {
                        ProgressView()
                            .tint(HiAirColors.Cta.gradientStart)
                        Text(session.l("auth.working"))
                            .font(HiAirTypography.bodyMD)
                            .foregroundStyle(HiAirV2Theme.primaryText)
                    }
                    .padding(HiAirSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: HiAirRadius.md)
                            .fill(TimeOfDayBackground.surfaceSecondary().opacity(0.95))
                    )
                }
            }
        }
        .hiAirPageBackground()
        .onAppear {
            viewModel.resetForDisplay()
        }
    }
}
