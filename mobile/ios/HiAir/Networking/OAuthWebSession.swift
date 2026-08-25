import AuthenticationServices
import UIKit

enum OAuthSignInError: LocalizedError {
    case cancelled
    case callbackMissing
    case presentationUnavailable

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "OAuth sign-in was cancelled."
        case .callbackMissing:
            return "OAuth callback was missing."
        case .presentationUnavailable:
            return "OAuth sign-in could not find a window to present from."
        }
    }
}

@MainActor
protocol OAuthWebSessionStarting: AnyObject {
    func start(url: URL, callbackScheme: String) async throws -> URL
}

/// In-app OAuth browser (ASWebAuthenticationSession) — Guideline 4.
/// Must not fall back to `UIApplication.shared.open` / external Safari.
@MainActor
final class SystemOAuthWebSession: NSObject, OAuthWebSessionStarting, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?

    func start(url: URL, callbackScheme: String) async throws -> URL {
        if let existing = continuation {
            continuation = nil
            existing.resume(throwing: OAuthSignInError.cancelled)
        }
        activeSession?.cancel()
        activeSession = nil
        guard AuthPresentationAnchor.currentWindow() != nil else {
            throw OAuthSignInError.presentationUnavailable
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.continuation = continuation
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.finish(callbackURL: callbackURL, error: error)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            if !session.start() {
                self.finish(callbackURL: nil, error: OAuthSignInError.callbackMissing)
            }
        }
    }

    private func finish(callbackURL: URL?, error: Error?) {
        activeSession = nil
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            let nsError = error as NSError
            if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                continuation.resume(throwing: OAuthSignInError.cancelled)
            } else if error is OAuthSignInError {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(throwing: error)
            }
            return
        }
        guard let callbackURL else {
            continuation.resume(throwing: OAuthSignInError.callbackMissing)
            return
        }
        continuation.resume(returning: callbackURL)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        AuthPresentationAnchor.currentWindow() ?? ASPresentationAnchor()
    }
}
