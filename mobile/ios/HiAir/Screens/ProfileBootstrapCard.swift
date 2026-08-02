import SwiftUI

/// Shared empty-state CTA for automatic profile bootstrap with visible loading/error contract.
struct ProfileBootstrapCard: View {
    @EnvironmentObject var session: AppSession
    var locationService: LocationProviding = LocationService.shared
    var titleKey: String = "dashboard.empty.no_profile.title"
    var bodyKey: String = "dashboard.empty.no_profile.body"
    var ctaKey: String = "dashboard.empty.no_profile.cta"
    var ctaAccessibilityID: String = HiAirAccessibilityID.Dashboard.createProfileCTA
    var usePrimaryStyle: Bool = true
    var onReady: (() async -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.l(titleKey))
                .font(HiAirTypography.titleMD)
                .foregroundStyle(HiAirV2Theme.primaryText)
            Text(session.l(resolvedBodyKey))
                .font(HiAirTypography.bodyMD)
                .foregroundStyle(HiAirV2Theme.secondaryText)

            if session.isEnsuringProfile {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(HiAirV2Theme.accentStart)
                    Text(session.l("profile.ensure.creating"))
                        .font(HiAirTypography.bodyMD)
                        .foregroundStyle(HiAirV2Theme.secondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(HiAirAccessibilityID.ProfileEnsure.loading)

            }

            if let message = session.profileEnsureUserMessage, !session.isEnsuringProfile {
                Text(message)
                    .font(HiAirTypography.bodyMD)
                    .foregroundStyle(HiAirColors.Risk.high)
                    .accessibilityIdentifier(HiAirAccessibilityID.ProfileEnsure.error)
            }

            createButton

            if shouldShowLocationRecovery {
                HStack(spacing: 10) {
                    Button(session.l("location.retry")) {
                        Task {
                            _ = await session.bootstrapLocationFromDevice(locationService: locationService)
                            await createProfileTapped()
                        }
                    }
                    .buttonStyle(HiAirSecondaryButtonStyle())
                    .accessibilityIdentifier(HiAirAccessibilityID.ProfileEnsure.locationAction)

                    if locationService.authorizationStatus == .denied
                        || locationService.authorizationStatus == .restricted {
                        Button(session.l("location.open_settings")) {
                            locationService.openAppSettings()
                        }
                        .buttonStyle(HiAirSecondaryButtonStyle())
                    }
                }
            }

            if case .failure(let reason) = session.lastProfileEnsureOutcome, reason.suggestsPaywall {
                Button(session.l("settings.upgrade_premium")) {
                    session.showPaywall = true
                }
                .buttonStyle(HiAirSecondaryButtonStyle())
                .accessibilityIdentifier(HiAirAccessibilityID.Settings.openPaywall)
            }
        }
        .v2Card()
    }

    /// Location CTA only for proven location blockers — never for API/auth/network failures.
    private var shouldShowLocationRecovery: Bool {
        guard !session.isEnsuringProfile else { return false }
        return session.lastProfileEnsureOutcome?.suggestsLocationRecovery == true
    }

    private var resolvedBodyKey: String {
        if let outcome = session.lastProfileEnsureOutcome, outcome.messageKey != nil {
            return bodyKey
        }
        return bodyKey
    }

    private var resolvedCtaKey: String {
        guard let outcome = session.lastProfileEnsureOutcome else { return ctaKey }
        switch outcome.category {
        case .network, .server, .decode, .unknown:
            return "profile.ensure.retry"
        case .auth:
            // Only expired session needs Sign in; 403 stays Retry (already authenticated).
            if case .needsAuthentication = outcome {
                return "auth.sign_in"
            }
            return "profile.ensure.retry"
        case .location:
            return "location.retry"
        case .cancelled, .none:
            return ctaKey
        }
    }

    @ViewBuilder
    private var createButton: some View {
        let title = session.isEnsuringProfile ? session.l("profile.ensure.creating") : session.l(resolvedCtaKey)
        if usePrimaryStyle {
            Button(title) {
                Task { await createProfileTapped() }
            }
            .buttonStyle(HiAirGradientButtonStyle())
            .disabled(session.isEnsuringProfile)
            .accessibilityIdentifier(ctaAccessibilityID)
        } else {
            Button(title) {
                Task { await createProfileTapped() }
            }
            .buttonStyle(HiAirSecondaryButtonStyle())
            .disabled(session.isEnsuringProfile)
            .accessibilityIdentifier(ctaAccessibilityID)
        }
    }

    @MainActor
    private func createProfileTapped() async {
        if case .needsAuthentication = session.lastProfileEnsureOutcome {
            // Session already expired — Auth UI owns recovery; do not loop ensure.
            return
        }
        // Only bootstrap location when recovery is location-scoped (or still unknown / empty).
        if session.lastProfileEnsureOutcome?.suggestsLocationRecovery == true
            || (session.lastProfileEnsureOutcome == nil && !session.hasValidLocation) {
            _ = await session.bootstrapLocationFromDevice(locationService: locationService)
        }
        // Explicit Retry / CTA — new ensure cycle (must not reuse the prior terminal failure).
        session.beginExplicitProfileEnsureCycle()
        let outcome = await session.ensureProfileIdIfNeeded()
        if outcome.isReady {
            session.markChecklistItem("profile", done: true)
            await onReady?()
        }
    }
}
