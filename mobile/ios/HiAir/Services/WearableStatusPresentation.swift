import Foundation

/// Presentation helpers that separate device HealthKit authorization from
/// account-bound sync consent. "Connected" is reserved for current-user
/// durable + (when known) server-active consent — never OS auth alone.
enum WearableStatusPresentation {
    /// Account-level sync is connected only when durable consent exists for
    /// the current user and the caller affirms consent is active.
    static func isAccountSyncConnected(
        connectionState: WearableConnectionState,
        hasDurableConsent: Bool,
        consentActive: Bool
    ) -> Bool {
        guard hasDurableConsent, consentActive else { return false }
        switch connectionState {
        case .connected, .dataUnavailable, .syncFailed, .partial:
            return true
        case .notConnected, .permissionRequested, .systemAuthorized, .consentSaving,
             .consentFailed, .revoking, .remoteRevokePending, .revokeFailed,
             .permissionDenied, .unavailable:
            return false
        }
    }

    /// Localized Wearables status line for Settings.
    /// - Parameters:
    ///   - consentActive: server (or reconciled) account consent is active for current user
    ///   - hasDurableConsent: local durable consent marker for current user
    ///   - hasSystemAuthorization: OS / prior sheet completed for current user
    static func statusLabel(
        connectionState: WearableConnectionState,
        consentActive: Bool,
        hasDurableConsent: Bool,
        hasSystemAuthorization: Bool,
        localize: (String) -> String
    ) -> String {
        let prefix = localize("settings.wearables.status")
        if isAccountSyncConnected(
            connectionState: connectionState,
            hasDurableConsent: hasDurableConsent,
            consentActive: consentActive
        ) {
            return "\(prefix): \(localize("settings.wearables.connected"))"
        }

        switch connectionState {
        case .consentSaving:
            return "\(prefix): \(localize("wearable.consent.saving"))"
        case .consentFailed:
            return "\(prefix): \(localize("wearable.consent.failed"))"
        case .revoking, .remoteRevokePending:
            return "\(prefix): \(localize("wearable.consent.revoking"))"
        case .revokeFailed:
            return "\(prefix): \(localize("wearable.consent.revoke_failed"))"
        case .permissionDenied:
            return "\(prefix): \(localize("settings.wearables.denied"))"
        case .unavailable:
            return localize("wearable.dashboard.unavailable")
        case .systemAuthorized:
            return "\(prefix): \(localize("settings.wearables.device_authorized"))"
        case .connected, .notConnected, .permissionRequested, .dataUnavailable, .syncFailed, .partial:
            // Stale `.connected` without durable+active consent must not say "подключено".
            if hasSystemAuthorization || connectionState == .systemAuthorized {
                return "\(prefix): \(localize("settings.wearables.device_authorized"))"
            }
            if hasDurableConsent && !consentActive {
                return "\(prefix): \(localize("settings.wearables.consent_inactive"))"
            }
            return localize("wearable.dashboard.not_connected")
        }
    }
}
