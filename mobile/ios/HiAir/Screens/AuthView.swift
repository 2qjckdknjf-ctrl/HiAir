import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loading = false
    @Published var statusText = "-"

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
            let response: AuthResponse
            if mode == "signup" {
                response = try await apiClient.signup(email: normalizedEmail, password: password)
            } else {
                response = try await apiClient.login(email: normalizedEmail, password: password)
            }
            session.userId = response.userId
            session.accessToken = response.accessToken
            statusText = session.l("auth.ok")
        } catch {
            statusText = session.l("auth.fail")
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AuroraTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.l("auth.title"))
                        .font(AuroraTokens.Typography.displayLG)
                        .foregroundStyle(HiAirV2Theme.primaryText)
                    Text("Aurora Calm v2")
                        .font(AuroraTokens.Typography.caption)
                        .foregroundStyle(HiAirV2Theme.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                VStack(spacing: 12) {
                    TextField(session.l("auth.email"), text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(HiAirV2Theme.primaryText)

                    SecureField(session.l("auth.password"), text: $viewModel.password)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(HiAirV2Theme.primaryText)
                }
                .v2Card()

                Button(viewModel.loading ? session.l("auth.signing_up") : session.l("auth.sign_up")) {
                    Task { await viewModel.signup(session: session) }
                }
                .buttonStyle(V2PrimaryButtonStyle())
                .disabled(viewModel.loading)

                Button(viewModel.loading ? session.l("auth.logging_in") : session.l("auth.log_in")) {
                    Task { await viewModel.login(session: session) }
                }
                .buttonStyle(V2PrimaryButtonStyle())
                .disabled(viewModel.loading)

                Text(viewModel.statusText)
                    .font(AuroraTokens.Typography.caption)
                    .foregroundStyle(HiAirV2Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .v2PageBackground()
    }
}
