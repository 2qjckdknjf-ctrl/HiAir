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
            Text(session.l(bodyKey))
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

            if session.lastProfileEnsureOutcome == .needsLocation {
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
        }
        .v2Card()
    }

    @ViewBuilder
    private var createButton: some View {
        let title = session.isEnsuringProfile ? session.l("profile.ensure.creating") : session.l(ctaKey)
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
        let outcome = await session.ensureProfileIdIfNeeded()
        if outcome.isReady {
            session.markChecklistItem("profile", done: true)
            await onReady?()
        }
    }
}
