import AuthenticationServices
import UIKit

/// Shared window lookup for Sign in with Apple and in-app Google OAuth.
/// Empty `ASPresentationAnchor()` is a known Apple error 1000 / silent Google sheet miss.
enum AuthPresentationAnchor {
    @MainActor
    static func currentWindow() -> ASPresentationAnchor? {
        let foregroundScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let foregroundWindows = foregroundScenes.flatMap(\.windows)
        if let key = foregroundWindows.first(where: \.isKeyWindow) {
            return key
        }
        if let visible = foregroundWindows.first(where: { !$0.isHidden && $0.alpha > 0 }) {
            return visible
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { !$0.isHidden && $0.alpha > 0 })
    }
}
