import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loading = false
    @Published var statusText = "-"

    private let supabaseAuth = SupabaseAuthService.shared

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
            let authSession: SupabaseAuthSession
            if mode == "signup" {
                authSession = try await supabaseAuth.signUp(email: normalizedEmail, password: password)
            } else {
                authSession = try await supabaseAuth.signIn(email: normalizedEmail, password: password)
            }
            session.userId = authSession.userId
            session.email = authSession.email
            session.accessToken = authSession.accessToken
            session.refreshToken = authSession.refreshToken
            session.authNotice = ""
            let hasProfile = await session.ensureProfileIdIfNeeded()
            if hasProfile {
                session.markChecklistItem("profile", done: true)
            }
            statusText = session.l("auth.ok")
        } catch is URLError {
            statusText = session.l("auth.backend_unreachable")
        } catch {
            statusText = session.l("auth.fail")
        }
    }

    func signInWithApple(session: AppSession) async {
        loading = true
        defer { loading = false }
        do {
            try await supabaseAuth.signInWithApple()
            statusText = session.l("auth.ok")
        } catch {
            statusText = session.l("auth.fail")
        }
    }

    func signInWithGoogle(session: AppSession) async {
        loading = true
        defer { loading = false }
        do {
            try await supabaseAuth.signInWithGoogle()
            statusText = session.l("auth.ok")
        } catch {
            statusText = session.l("auth.fail")
        }
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
