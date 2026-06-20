import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var loading = false
    @Published var statusText = "-"

    private let apiClient = APIClient.live()

    func signup(session: AppSession, onSuccess: (() -> Void)? = nil) async {
        await authenticate(session: session, mode: "signup", onSuccess: onSuccess)
    }

    func login(session: AppSession, onSuccess: (() -> Void)? = nil) async {
        await authenticate(session: session, mode: "login", onSuccess: onSuccess)
    }

    private func authenticate(session: AppSession, mode: String, onSuccess: (() -> Void)?) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else {
            statusText = session.l("auth.enter_email")
            return
        }
        guard password.count >= 8 else {
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
            onSuccess?()
        } catch {
            statusText = session.l("auth.fail")
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = AuthViewModel()
    var onAuthenticated: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text(session.l("auth.title"))
                .font(.title2)
                .bold()

            TextField(session.l("auth.email"), text: $viewModel.email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField(session.l("auth.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Button(viewModel.loading ? session.l("auth.signing_up") : session.l("auth.sign_up")) {
                    Task { await viewModel.signup(session: session, onSuccess: onAuthenticated) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.loading)

                Button(viewModel.loading ? session.l("auth.logging_in") : session.l("auth.log_in")) {
                    Task { await viewModel.login(session: session, onSuccess: onAuthenticated) }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.loading)
            }

            Text(viewModel.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
