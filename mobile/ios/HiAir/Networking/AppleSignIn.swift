import AuthenticationServices
import CryptoKit
import Foundation

enum AppleSignInError: LocalizedError, Equatable {
    case missingIdentityToken
    case missingAuthorizationCode
    case cancelled
    case presentationUnavailable

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple Sign In did not return an identity token."
        case .missingAuthorizationCode:
            return "Apple Sign In did not return an authorization code."
        case .cancelled:
            return "Apple Sign In was cancelled."
        case .presentationUnavailable:
            return "Apple Sign In could not find a window to present from."
        }
    }
}

struct AppleIDTokenPayload: Sendable {
    let userIdentifier: String
    let identityToken: Data?
    let authorizationCode: Data?
    let email: String?
}

@MainActor
protocol AppleSignInStarting: AnyObject {
    func signIn() async throws -> (credential: AppleIDTokenPayload, rawNonce: String)
}

enum AppleIDCredentialState: Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
}

@MainActor
protocol AppleIDCredentialStateChecking: AnyObject {
    func state(forUserID userID: String) async -> AppleIDCredentialState
}

protocol AppleUserIdentifierStoring: AnyObject {
    func save(_ identifier: String)
    func current() -> String?
    func clear()
}

enum AppleSignInNonce {
    static func randomString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset.randomElement()!)
        }
        return result
    }

    /// SHA-256 hex, matching Apple's sample and Supabase GoTrue nonce verify.
    static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

final class KeychainAppleUserIdentifierStore: AppleUserIdentifierStoring {
    static let accountKey = "session.appleUserIdentifier"
    private let store: any SessionCredentialStoring

    init(store: any SessionCredentialStoring = KeychainStore(service: "com.hiair.app.session")) {
        self.store = store
    }

    func save(_ identifier: String) {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.deleteValue(forKey: Self.accountKey)
            return
        }
        store.setString(trimmed, forKey: Self.accountKey)
    }

    func current() -> String? {
        store.getString(forKey: Self.accountKey)
    }

    func clear() {
        store.deleteValue(forKey: Self.accountKey)
    }
}

final class InMemoryAppleUserIdentifierStore: AppleUserIdentifierStoring {
    private var value: String?

    func save(_ identifier: String) {
        value = identifier
    }

    func current() -> String? {
        value
    }

    func clear() {
        value = nil
    }
}

@MainActor
final class SystemAppleIDCredentialStateChecker: AppleIDCredentialStateChecking {
    func state(forUserID userID: String) async -> AppleIDCredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                switch state {
                case .authorized:
                    continuation.resume(returning: .authorized)
                case .revoked:
                    continuation.resume(returning: .revoked)
                case .notFound:
                    continuation.resume(returning: .notFound)
                case .transferred:
                    continuation.resume(returning: .transferred)
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }
}

@MainActor
final class AppleSignInCoordinator: NSObject, AppleSignInStarting {
    private var continuation: CheckedContinuation<(credential: AppleIDTokenPayload, rawNonce: String), Error>?
    private var currentNonce = ""
    /// Must be retained until the delegate fires — local `ASAuthorizationController` is a classic error 1000.
    private var authorizationController: ASAuthorizationController?

    func signIn() async throws -> (credential: AppleIDTokenPayload, rawNonce: String) {
        if let existing = continuation {
            continuation = nil
            existing.resume(throwing: AppleSignInError.cancelled)
        }
        authorizationController = nil
        guard AuthPresentationAnchor.currentWindow() != nil else {
            throw AppleSignInError.presentationUnavailable
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(credential: AppleIDTokenPayload, rawNonce: String), Error>) in
            self.continuation = continuation
            currentNonce = AppleSignInNonce.randomString()
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = AppleSignInNonce.sha256Hex(currentNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller
            controller.performRequests()
        }
    }

    func authorizationCodeForAccountDeletion() async throws -> String {
        let (credential, _) = try await signIn()
        guard let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8),
              !code.isEmpty
        else {
            throw AppleSignInError.missingAuthorizationCode
        }
        return code
    }

    private func finish(_ result: Result<(credential: AppleIDTokenPayload, rawNonce: String), Error>) {
        authorizationController = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AppleSignInError.missingIdentityToken))
            return
        }
        guard credential.identityToken != nil else {
            finish(.failure(AppleSignInError.missingIdentityToken))
            return
        }
        let payload = AppleIDTokenPayload(
            userIdentifier: credential.user,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            email: credential.email
        )
        finish(.success((credential: payload, rawNonce: currentNonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            finish(.failure(AppleSignInError.cancelled))
        } else {
            finish(.failure(error))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        AuthPresentationAnchor.currentWindow() ?? ASPresentationAnchor()
    }
}
